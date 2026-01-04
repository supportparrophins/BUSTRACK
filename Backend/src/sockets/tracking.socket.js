const LiveLocation = require("../models/livelocation");
const TripHistory = require("../models/triphistory");

// Track locked routes: { route_id: { socket_id, bus_id, locked_at } }
const lockedRoutes = new Map();

module.exports = (io) => {

  io.on("connection", (socket) => {
    console.log("Client connected:", socket.id);
    
    // Store driver info on socket for cleanup later
    socket.driverData = null;

    // Driver authenticates and locks route
    socket.on("authenticate_driver", async (data) => {
      const { bus_id, route_id, vehicle_number } = data;
      console.log(`🔐 Driver authentication attempt - Bus: ${bus_id}, Route: ${route_id}, Socket: ${socket.id}`);

      try {
        // Check if route is already locked by another driver
        if (lockedRoutes.has(route_id)) {
          const lockInfo = lockedRoutes.get(route_id);
          
          // Check if it's the same socket trying to reconnect
          if (lockInfo.socket_id !== socket.id) {
            console.log(`❌ Route ${route_id} is already locked by socket ${lockInfo.socket_id}`);
            socket.emit("route_locked", {
              success: false,
              message: `This route is already being tracked by another driver (${lockInfo.vehicle_number || 'Unknown'})`,
              locked_by: lockInfo.bus_id,
              locked_at: lockInfo.locked_at
            });
            return;
          }
        }

        // Lock the route
        lockedRoutes.set(route_id, {
          socket_id: socket.id,
          bus_id: bus_id,
          vehicle_number: vehicle_number,
          locked_at: new Date()
        });

        // Store driver data on socket for cleanup
        socket.driverData = { bus_id, route_id, vehicle_number };

        console.log(`✅ Route ${route_id} locked by driver ${bus_id} (${vehicle_number}) - Socket: ${socket.id}`);
        console.log(`🔒 Currently locked routes:`, Array.from(lockedRoutes.keys()));

        // Send success response
        socket.emit("route_lock_success", {
          success: true,
          message: "Route locked successfully. You can now start tracking.",
          route_id: route_id,
          bus_id: bus_id
        });
      } catch (error) {
        console.error("Error in authenticate_driver:", error);
        socket.emit("route_locked", {
          success: false,
          message: "Failed to lock route. Please try again."
        });
      }
    });

    // Student joins route
    socket.on("join_route", async (data) => {
      console.log(`Socket ${socket.id} joining route:`, data.route_id);
      socket.join(`route_${data.route_id}`);
      console.log(`Socket ${socket.id} successfully joined route_${data.route_id}`);

      // Send current location immediately to the joining student
      try {
        const currentLocation = await LiveLocation.findOne({ route_id: data.route_id });
        if (currentLocation) {
          socket.emit("location_update", {
            bus_id: currentLocation.bus_id,
            lat: currentLocation.lat,
            lng: currentLocation.lng,
            speed: currentLocation.speed,
            start_lat: currentLocation.start_lat,  // Send starting location
            start_lng: currentLocation.start_lng,
            route_points: currentLocation.active_route_points || []  // Send entire route
          });
          console.log(`Sent current location to ${socket.id} for route_${data.route_id}`);
        } else {
          console.log(`No location found for route_${data.route_id}`);
        }
      } catch (error) {
        console.error("Error fetching current location:", error);
      }
    });

    // Bus sends location
    socket.on("bus_location", async (data) => {
      const { bus_id, route_id, lat, lng, speed } = data;
      console.log("Received bus location:", { bus_id, route_id, lat, lng, speed });

      // Verify route is locked by this driver
      if (!lockedRoutes.has(route_id) || lockedRoutes.get(route_id).socket_id !== socket.id) {
        console.log(`⚠️ Unauthorized location update attempt for route ${route_id} by socket ${socket.id}`);
        socket.emit("route_not_locked", {
          success: false,
          message: "You must authenticate first before sending location updates."
        });
        return;
      }

      try {
        let existingLocation = await LiveLocation.findOne({ bus_id });
        const currentTime = new Date();
        
        let updateData = {
          lat,
          lng,
          speed,
          route_id,
          updated_at: currentTime
        };

        // If trip_active is false or missing, start new trip
        if (!existingLocation || !existingLocation.trip_active) {
          updateData.start_lat = lat;
          updateData.start_lng = lng;
          updateData.trip_active = true;
          updateData.trip_start_time = currentTime;
          updateData.active_route_points = [{ lat, lng, timestamp: currentTime }];
          console.log(`🚀 New trip started for bus_id ${bus_id}: (${lat}, ${lng})`);
        } else {
          // Add current point to active route only if it's different from last point
          const routePoints = existingLocation.active_route_points || [];
          const lastPoint = routePoints[routePoints.length - 1];
          
          // Check if location has changed (avoid saving duplicate points)
          const hasLocationChanged = !lastPoint || 
            lastPoint.lat !== lat || 
            lastPoint.lng !== lng;
          
          if (hasLocationChanged) {
            routePoints.push({ lat, lng, timestamp: currentTime });
            updateData.active_route_points = routePoints;
            console.log(`📍 New point added to route for bus_id ${bus_id}`);
          } else {
            // Don't add duplicate point, but still update route_points to keep array
            updateData.active_route_points = routePoints;
            console.log(`⏭️ Skipped duplicate point for bus_id ${bus_id}`);
          }
        }

        // save to MongoDB (latest location)
        await LiveLocation.updateOne(
          { bus_id },
          { $set: updateData },
          { upsert: true }
        );

        // Get updated location to broadcast (includes start location and route)
        const updatedLocation = await LiveLocation.findOne({ bus_id });
        console.log(`Location updated in DB for bus_id: ${bus_id} | Route points: ${updatedLocation.active_route_points.length}`);

        // broadcast to students of this route
        io.to(`route_${route_id}`).emit("location_update", {
          bus_id,
          lat,
          lng,
          speed,
          start_lat: updatedLocation.start_lat,
          start_lng: updatedLocation.start_lng,
          route_points: updatedLocation.active_route_points  // Send entire route to all clients
        });
        console.log(`Location emitted to route_${route_id}`);
      } catch (error) {
        console.error("Error updating location:", error);
      }
    });

    // Bus ends trip - save to history and reset
    socket.on("end_trip", async (data) => {
      const { bus_id } = data;
      console.log(`Ending trip for bus_id: ${bus_id}`);

      try {
        // Get current trip data before clearing
        const currentTrip = await LiveLocation.findOne({ bus_id });
        
        if (currentTrip && currentTrip.trip_active && currentTrip.active_route_points && currentTrip.active_route_points.length > 0) {
          // Save trip to history
          const tripHistory = new TripHistory({
            bus_id: currentTrip.bus_id,
            route_id: currentTrip.route_id,
            start_time: currentTrip.trip_start_time || currentTrip.active_route_points[0].timestamp,
            end_time: new Date(),
            route_points: currentTrip.active_route_points,
            total_points: currentTrip.active_route_points.length
          });
          
          await tripHistory.save();
          console.log(`✅ Trip history saved - Bus: ${bus_id}, Route: ${currentTrip.route_id}, Points: ${currentTrip.active_route_points.length}`);
        } else {
          console.log(`⚠️ No active trip data to save for bus_id: ${bus_id}`);
        }

        // Clear the trip data and mark as inactive
        await LiveLocation.updateOne(
          { bus_id },
          {
            $unset: { start_lat: "", start_lng: "", trip_start_time: "" },
            $set: { 
              trip_active: false,
              active_route_points: []  // Clear route points for new trip
            }
          }
        );
        console.log(`🔄 Trip ended and reset for bus_id: ${bus_id}`);
        
        // Notify clients that trip has ended
        if (currentTrip) {
          // Unlock the route
          if (lockedRoutes.has(currentTrip.route_id)) {
            lockedRoutes.delete(currentTrip.route_id);
            console.log(`🔓 Route ${currentTrip.route_id} unlocked after trip end`);
            console.log(`🔒 Currently locked routes:`, Array.from(lockedRoutes.keys()));
          }

          io.to(`route_${currentTrip.route_id}`).emit("trip_ended", {
            bus_id: bus_id
          });
        }
      } catch (error) {
        console.error("Error ending trip:", error);
      }
    });

    socket.on("disconnect", () => {
      console.log("Client disconnected:", socket.id);
      
      // Unlock route if this was a driver
      if (socket.driverData) {
        const { route_id, bus_id, vehicle_number } = socket.driverData;
        if (lockedRoutes.has(route_id) && lockedRoutes.get(route_id).socket_id === socket.id) {
          lockedRoutes.delete(route_id);
          console.log(`🔓 Route ${route_id} unlocked due to driver ${bus_id} (${vehicle_number}) disconnect`);
          console.log(`🔒 Currently locked routes:`, Array.from(lockedRoutes.keys()));
          
          // Notify students that tracking has stopped
          io.to(`route_${route_id}`).emit("tracking_stopped", {
            route_id: route_id,
            message: "Driver has disconnected. Tracking stopped."
          });
        }
      }
    });
  });
};

// Export function to get locked routes for API endpoint
module.exports.getLockedRoutes = () => {
  const routes = [];
  lockedRoutes.forEach((value, key) => {
    routes.push({
      route_id: key,
      bus_id: value.bus_id,
      vehicle_number: value.vehicle_number,
      socket_id: value.socket_id,
      locked_at: value.locked_at
    });
  });
  return routes;
};

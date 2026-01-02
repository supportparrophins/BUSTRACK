const mongoose = require("mongoose");

const RoutePointSchema = new mongoose.Schema({
  lat: Number,
  lng: Number,
  timestamp: Date
}, { _id: false });

module.exports = mongoose.model(
  "LiveLocation",
  new mongoose.Schema({
    bus_id: Number,
    route_id: Number,
    lat: Number,
    lng: Number,
    speed: Number,
    start_lat: Number,  // Starting location latitude
    start_lng: Number,  // Starting location longitude
    updated_at: Date,
    trip_active: { type: Boolean, default: false },
    trip_start_time: Date,  // When current trip started
    active_route_points: [RoutePointSchema]  // Current trip route points
  })
);

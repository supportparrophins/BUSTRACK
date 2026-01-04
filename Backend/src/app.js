const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
require("dotenv").config();
require("./config/db");

const app = express();
app.use(require("cors")());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const trackingSocket = require("./sockets/tracking.socket");
trackingSocket(io);

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok", message: "Bus Tracker API is running" });
});

// Get locked routes (for debugging)
app.get("/locked-routes", (req, res) => {
  try {
    const lockedRoutes = trackingSocket.getLockedRoutes();
    res.json({
      success: true,
      locked_routes: lockedRoutes,
      count: lockedRoutes.length
    });
  } catch (error) {
    res.json({
      success: true,
      locked_routes: [],
      count: 0,
      note: "getLockedRoutes not available"
    });
  }
});

module.exports = server;

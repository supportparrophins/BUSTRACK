const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
require("dotenv").config();
require("./config/db");

const app = express();
app.use(require("cors")());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

require("./sockets/tracking.socket")(io);

module.exports = server;

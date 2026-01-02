const mongoose = require("mongoose");

const RoutePointSchema = new mongoose.Schema({
  lat: Number,
  lng: Number,
  timestamp: Date
}, { _id: false });

const TripHistorySchema = new mongoose.Schema({
  bus_id: {
    type: Number,
    required: true
  },
  route_id: {
    type: Number,
    required: true
  },
  start_time: {
    type: Date,
    required: true
  },
  end_time: {
    type: Date,
    required: true
  },
  route_points: {
    type: [RoutePointSchema],
    required: true
  },
  total_points: {
    type: Number,
    required: true
  }
}, {
  timestamps: true
});

// Create indexes for better query performance
TripHistorySchema.index({ bus_id: 1, end_time: -1 });
TripHistorySchema.index({ route_id: 1, end_time: -1 });

module.exports = mongoose.model("TripHistory", TripHistorySchema);

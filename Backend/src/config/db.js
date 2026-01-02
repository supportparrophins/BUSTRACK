const mongoose = require("mongoose");

mongoose.connect(process.env.MONGO_URL)
  .then(() => console.log("MongoDB connected (LOCAL)"))
  .catch(err => console.error("MongoDB error:", err));

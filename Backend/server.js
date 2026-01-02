const server = require("./src/app");

server.listen(process.env.PORT, () => {
  console.log("Bus Tracker running on port", process.env.PORT);
});

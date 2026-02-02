const { register } = require("../services/metrics");

const metrics = async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
};

module.exports = { metrics };

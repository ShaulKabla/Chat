const { getMaintenanceState } = require("../services/maintenance");

const getConfig = (redisClient) => async (req, res) => {
  const maintenance = await getMaintenanceState(redisClient);
  res.json({
    version: process.env.APP_VERSION || "2.0.0",
    maintenance,
    features: {
      reporting: true,
      blocking: true,
      notifications: true,
      logs: true
    }
  });
};

module.exports = { getConfig };

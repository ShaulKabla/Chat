const { getMaintenanceState } = require("../services/maintenance");

const getMaintenance = (redisClient) => async (req, res) => {
  const maintenance = await getMaintenanceState(redisClient);
  res.json(maintenance);
};

module.exports = { getMaintenance };

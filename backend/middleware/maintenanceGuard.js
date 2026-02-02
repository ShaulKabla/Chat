const { getMaintenanceState } = require("../services/maintenance");

const maintenanceGuard = (redisClient) => async (req, res, next) => {
  if (
    req.path.startsWith("/admin") ||
    req.path === "/config" ||
    req.path === "/maintenance" ||
    req.path.startsWith("/internal")
  ) {
    return next();
  }
  const state = await getMaintenanceState(redisClient);
  if (state.enabled) {
    return res.status(503).json({ error: "maintenance", message: state.message });
  }
  return next();
};

module.exports = maintenanceGuard;

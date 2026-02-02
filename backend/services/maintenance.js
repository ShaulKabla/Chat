const maintenanceDefaults = {
  enabled: "false",
  message:
    process.env.MAINTENANCE_MESSAGE ||
    "We are performing scheduled maintenance. Please try again shortly."
};

const ensureMaintenanceDefaults = async (redisClient) => {
  const existing = await redisClient.hGetAll("maintenance");
  if (!existing.enabled) {
    await redisClient.hSet("maintenance", maintenanceDefaults);
  }
};

const getMaintenanceState = async (redisClient) => {
  const data = await redisClient.hGetAll("maintenance");
  return {
    enabled: data.enabled === "true",
    message: data.message || maintenanceDefaults.message
  };
};

const setMaintenanceState = async (redisClient, { enabled, message }) => {
  await redisClient.hSet("maintenance", {
    enabled: String(Boolean(enabled)),
    message: message || maintenanceDefaults.message
  });
};

module.exports = {
  ensureMaintenanceDefaults,
  getMaintenanceState,
  setMaintenanceState
};

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const { addLog } = require("../services/logStream");
const { setMaintenanceState, getMaintenanceState } = require("../services/maintenance");

const adminLogin = (redisClient) => async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: "Missing credentials" });
  }
  const adminUser = process.env.ADMIN_USER;
  const adminPass = process.env.ADMIN_PASS;
  const passwordOk = await bcrypt.compare(password, await bcrypt.hash(adminPass, 10));
  if (username !== adminUser || !passwordOk) {
    return res.status(401).json({ error: "Invalid credentials" });
  }
  const token = jwt.sign({ username, type: "admin" }, process.env.JWT_SECRET, {
    expiresIn: "8h",
    jwtid: uuidv4()
  });
  addLog("info", "Admin logged in", { username, requestId: req.requestId });
  return res.json({ token });
};

const adminLogout = (redisClient) => async (req, res) => {
  if (!req.user?.jti) {
    return res.status(400).json({ error: "Missing token id" });
  }
  await redisClient.sAdd("revoked_tokens", req.user.jti);
  return res.json({ status: "ok" });
};

const getStats =
  (pool, redisClient, { getBackendInstanceCount, getActiveConnections, getQueueLength }) =>
  async (req, res) => {
  try {
    const [reportCount, waitingUsers, backendInstances] = await Promise.all([
      pool.query("SELECT COUNT(*) FROM reports"),
      getQueueLength(),
      getBackendInstanceCount()
    ]);
    return res.json({
      connectedUsers: Number(getActiveConnections()),
      waitingUsers: Number(waitingUsers || 0),
      reports: Number(reportCount.rows[0].count || 0),
      backendInstances: Number(backendInstances || 1)
    });
  } catch (err) {
    addLog("error", "Stats error", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Failed to load stats" });
  }
};

const getReported = (pool) => async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT id, reporter_id, reported_id, reason, image_url, created_at FROM reports ORDER BY created_at DESC LIMIT 100"
    );
    return res.json({ reports: rows });
  } catch (err) {
    addLog("error", "Reported list error", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Failed to load reports" });
  }
};

const revokeUserTokens = async (redisClient, userId) => {
  const tokens = await redisClient.sMembers(`user_tokens:${userId}`);
  if (tokens.length) {
    await redisClient.sAdd("revoked_tokens", tokens);
  }
};

const banUser = (pool, redisClient, io, socketByUser) => async (req, res) => {
  const { userId, reason } = req.body;
  if (!userId) {
    return res.status(400).json({ error: "Missing userId" });
  }
  try {
    await pool.query("INSERT INTO bans (user_id, reason) VALUES ($1, $2)", [
      userId,
      reason || "admin"
    ]);
    await redisClient.sAdd("banned_users", userId);
    await revokeUserTokens(redisClient, userId);
    const socketId = socketByUser?.get(userId);
    if (socketId) {
      io.to(socketId).emit("banned", { message: reason || "admin" });
      io.in(socketId).disconnectSockets(true);
    }
    addLog("info", "User banned", { userId, reason, requestId: req.requestId });
    return res.json({ status: "ok" });
  } catch (err) {
    addLog("error", "Ban error", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Failed to ban user" });
  }
};

const updateMaintenance = (redisClient, io) => async (req, res) => {
  const { enabled, message } = req.body || {};
  await setMaintenanceState(redisClient, { enabled, message });
  const maintenance = await getMaintenanceState(redisClient);
  if (io) {
    io.emit("maintenance_mode", maintenance);
  }
  addLog("info", "Maintenance mode updated", { ...maintenance, requestId: req.requestId });
  return res.json(maintenance);
};

const getSystemSnapshot =
  (redisClient, { getActiveMatches, getQueueLength, getMediaCleanupStatus }) =>
  async (req, res) => {
    try {
      const [usersInQueue, activeMatches, mediaCleanupStatus] = await Promise.all([
        getQueueLength(),
        getActiveMatches(),
        getMediaCleanupStatus()
      ]);
      return res.json({
        active_matches: Number(activeMatches || 0),
        users_in_queue: Number(usersInQueue || 0),
        media_cleanup_status: mediaCleanupStatus
      });
    } catch (err) {
      addLog("error", "System snapshot error", { error: err.message, requestId: req.requestId });
      return res.status(500).json({ error: "Failed to load system snapshot" });
    }
  };

module.exports = {
  adminLogin,
  adminLogout,
  getStats,
  getReported,
  banUser,
  updateMaintenance,
  getSystemSnapshot
};

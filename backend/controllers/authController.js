const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const { addLog } = require("../services/logStream");

const registerAnonymous = (pool, redisClient) => async (req, res) => {
  const fcmToken = String(req.body?.fcmToken || "").trim();
  if (!fcmToken) {
    return res.status(400).json({ error: "Missing fcmToken" });
  }
  const userId = uuidv4();
  try {
    await pool.query(
      "INSERT INTO anonymous_users (user_id, fcm_token) VALUES ($1, $2)",
      [userId, fcmToken]
    );
    await redisClient.hSet("user_fcm_tokens", userId, fcmToken);
    const jti = uuidv4();
    const token = jwt.sign({ sub: userId, type: "anonymous" }, process.env.JWT_SECRET, {
      expiresIn: "30d",
      jwtid: jti
    });
    await redisClient.sAdd(`user_tokens:${userId}`, jti);
    await redisClient.expire(`user_tokens:${userId}`, 60 * 60 * 24 * 30);
    addLog("info", "Anonymous user registered", { userId, requestId: req.requestId });
    return res.json({ userId, token });
  } catch (err) {
    addLog("error", "Anonymous auth error", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Failed to register" });
  }
};

module.exports = { registerAnonymous };

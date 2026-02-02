const jwt = require("jsonwebtoken");

const isTokenRevoked = async (redisClient, jti) => {
  if (!jti) return false;
  const revoked = await redisClient.sIsMember("revoked_tokens", jti);
  return revoked === 1;
};

const ensureAuth = (redisClient) => async (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing token" });
  }
  const token = auth.replace("Bearer ", "");
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (await isTokenRevoked(redisClient, decoded.jti)) {
      return res.status(401).json({ error: "Token revoked" });
    }
    req.user = decoded;
    return next();
  } catch (err) {
    return res.status(401).json({ error: "Invalid token" });
  }
};

const ensureAdmin = (req, res, next) => {
  if (req.user?.type !== "admin") {
    return res.status(403).json({ error: "Admin access required" });
  }
  return next();
};

const ensureNotBanned = (redisClient) => async (req, res, next) => {
  if (req.user?.sub) {
    const banned = await redisClient.sIsMember("banned_users", req.user.sub);
    if (banned === 1) {
      return res.status(403).json({ error: "User is banned" });
    }
  }
  return next();
};

module.exports = {
  ensureAuth,
  ensureAdmin,
  ensureNotBanned,
  isTokenRevoked
};

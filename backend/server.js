require("dotenv").config();
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { Pool } = require("pg");
const { createClient } = require("redis");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const { v4: uuidv4 } = require("uuid");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const adminNamespace = io.of("/admin");

app.use(helmet());
app.use(cors());
app.use(express.json());
app.set("trust proxy", process.env.TRUST_PROXY || "loopback");

const limiter = rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 900000),
  max: Number(process.env.RATE_LIMIT_MAX || 200),
  standardHeaders: true,
  legacyHeaders: false
});

app.use(limiter);
app.use("/api", maintenanceGuard);

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD
});

const redisClient = createClient({ url: process.env.REDIS_URL });
redisClient.on("error", (err) => console.error("Redis error", err));
const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

const connectRedis = async () => {
  await redisClient.connect();
  await pubClient.connect();
  await subClient.connect();
  io.adapter(createAdapter(pubClient, subClient));
};

const logBuffer = [];
const logBufferSize = Number(process.env.LOG_BUFFER_SIZE || 200);

const maintenanceDefaults = {
  enabled: "false",
  message:
    process.env.MAINTENANCE_MESSAGE ||
    "We are performing scheduled maintenance. Please try again shortly."
};

const addLog = (level, message, meta = {}) => {
  const entry = {
    id: uuidv4(),
    timestamp: new Date().toISOString(),
    level,
    message,
    meta
  };
  logBuffer.push(entry);
  if (logBuffer.length > logBufferSize) {
    logBuffer.shift();
  }
  adminNamespace.emit("log:entry", entry);
  const output = `[${entry.timestamp}] ${level.toUpperCase()}: ${message}`;
  if (level === "error") {
    console.error(output, meta);
  } else {
    console.log(output, meta);
  }
};

const ensureMaintenanceDefaults = async () => {
  const existing = await redisClient.hGetAll("maintenance");
  if (!existing.enabled) {
    await redisClient.hSet("maintenance", maintenanceDefaults);
  }
};

const getMaintenanceState = async () => {
  const data = await redisClient.hGetAll("maintenance");
  return {
    enabled: data.enabled === "true",
    message: data.message || maintenanceDefaults.message
  };
};

const setMaintenanceState = async ({ enabled, message }) => {
  await redisClient.hSet("maintenance", {
    enabled: String(Boolean(enabled)),
    message: message || maintenanceDefaults.message
  });
};

const setSocketForUser = async (userId, socketId) => {
  await redisClient.hSet("user_sockets", userId, socketId);
  await redisClient.hSet("socket_users", socketId, userId);
};

const getSocketForUser = async (userId) => redisClient.hGet("user_sockets", userId);

const removeSocket = async (socketId) => {
  const userId = await redisClient.hGet("socket_users", socketId);
  if (!userId) return null;
  await redisClient.hDel("socket_users", socketId);
  await redisClient.hDel("user_sockets", userId);
  return userId;
};

const removeFromQueue = async (userId) => {
  await redisClient.lRem("waiting_queue", 0, userId);
};

const addToQueue = async (userId) => {
  await removeFromQueue(userId);
  await redisClient.rPush("waiting_queue", userId);
};

const setPairing = async (userA, userB) => {
  await redisClient.hSet("pairings", userA, userB);
  await redisClient.hSet("pairings", userB, userA);
};

const clearPairing = async (userId) => {
  const partnerId = await redisClient.hGet("pairings", userId);
  if (partnerId) {
    await redisClient.hDel("pairings", partnerId);
  }
  await redisClient.hDel("pairings", userId);
  return partnerId;
};

const isBlockedPair = async (userA, userB) => {
  const [blockedA, blockedB] = await Promise.all([
    redisClient.sIsMember(`blocked:${userA}`, userB),
    redisClient.sIsMember(`blocked:${userB}`, userA)
  ]);
  return blockedA === 1 || blockedB === 1;
};

const initDb = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id SERIAL PRIMARY KEY,
      reporter_id TEXT NOT NULL,
      reported_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bans (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS anonymous_users (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      fcm_token TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
};

initDb().catch((err) => {
  addLog("error", "Database initialization failed", { error: err.message });
  process.exit(1);
});

const isTokenRevoked = async (jti) => {
  if (!jti) return false;
  const revoked = await redisClient.sIsMember("revoked_tokens", jti);
  return revoked === 1;
};

const isBannedUser = async (userId) => {
  const banned = await redisClient.sIsMember("banned_users", userId);
  return banned === 1;
};

const ensureAuth = async (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing token" });
  }
  const token = auth.replace("Bearer ", "");
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (await isTokenRevoked(decoded.jti)) {
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

const ensureNotBanned = async (req, res, next) => {
  if (req.user?.sub && (await isBannedUser(req.user.sub))) {
    return res.status(403).json({ error: "User is banned" });
  }
  return next();
};

const maintenanceGuard = async (req, res, next) => {
  if (req.path.startsWith("/admin") || req.path === "/config" || req.path === "/maintenance") {
    return next();
  }
  const state = await getMaintenanceState();
  if (state.enabled) {
    return res.status(503).json({ error: "maintenance", message: state.message });
  }
  return next();
};

const pairUsers = async (userId) => {
  await removeFromQueue(userId);
  const waiting = await redisClient.lRange("waiting_queue", 0, -1);
  let partnerId = null;
  for (const candidate of waiting) {
    if (candidate === userId) continue;
    if (!(await isBlockedPair(userId, candidate))) {
      partnerId = candidate;
      await redisClient.lRem("waiting_queue", 0, candidate);
      break;
    }
  }

  if (!partnerId) {
    await addToQueue(userId);
    return;
  }

  await setPairing(userId, partnerId);
  const [socketA, socketB] = await Promise.all([
    getSocketForUser(userId),
    getSocketForUser(partnerId)
  ]);
  if (socketA) {
    io.to(socketA).emit("paired", { partnerId });
  }
  if (socketB) {
    io.to(socketB).emit("paired", { partnerId: userId });
  }
  addLog("info", "Users paired", { userId, partnerId });
};

const resolveUserId = async (socket) => {
  const token = socket.handshake.auth?.token;
  if (!token) {
    return uuidv4();
  }
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  if (await isTokenRevoked(decoded.jti)) {
    throw new Error("Token revoked");
  }
  if (await isBannedUser(decoded.sub)) {
    throw new Error("User banned");
  }
  return decoded.sub || uuidv4();
};

io.on("connection", async (socket) => {
  try {
    const maintenance = await getMaintenanceState();
    if (maintenance.enabled) {
      socket.emit("maintenance", { message: maintenance.message });
      socket.disconnect(true);
      return;
    }

    const userId = await resolveUserId(socket);
    await setSocketForUser(userId, socket.id);

    socket.emit("user:id", { userId });
    await pairUsers(userId);
    addLog("info", "User connected", { userId });

    socket.on("chat:message", async (payload) => {
      const partnerId = await redisClient.hGet("pairings", userId);
      if (!partnerId) {
        return;
      }
      const partnerSocketId = await getSocketForUser(partnerId);
      if (!partnerSocketId) {
        return;
      }
      io.to(partnerSocketId).emit("chat:message", {
        from: userId,
        message: String(payload?.message || "")
      });
    });

    socket.on("user:block", async (payload) => {
      const blockedId = String(payload?.blockedUserId || "");
      if (!blockedId) {
        return;
      }
      await redisClient.sAdd(`blocked:${userId}`, blockedId);

      const partnerId = await redisClient.hGet("pairings", userId);
      if (partnerId === blockedId) {
        await clearPairing(userId);
        const partnerSocketId = await getSocketForUser(partnerId);
        if (partnerSocketId) {
          io.to(partnerSocketId).emit("partner:disconnected", { reason: "blocked" });
        }
        await pairUsers(userId);
      }
    });

    socket.on("user:report", async (payload) => {
      const reportedId = String(payload?.reportedUserId || "");
      const reason = String(payload?.reason || "unspecified");
      if (!reportedId) {
        return;
      }
      try {
        await pool.query(
          "INSERT INTO reports (reporter_id, reported_id, reason) VALUES ($1, $2, $3)",
          [userId, reportedId, reason]
        );
        socket.emit("report:received", { status: "ok" });
        addLog("info", "User reported", { reporterId: userId, reportedId, reason });
      } catch (err) {
        addLog("error", "Report error", { error: err.message });
        socket.emit("report:received", { status: "error" });
      }
    });

    socket.on("disconnect", async () => {
      const disconnectedId = await removeSocket(socket.id);
      if (!disconnectedId) {
        return;
      }
      await redisClient.del(`blocked:${disconnectedId}`);
      await removeFromQueue(disconnectedId);

      const partnerId = await clearPairing(disconnectedId);
      if (partnerId) {
        const partnerSocketId = await getSocketForUser(partnerId);
        if (partnerSocketId) {
          io.to(partnerSocketId).emit("partner:disconnected", { reason: "left" });
          await pairUsers(partnerId);
        }
      }
      addLog("info", "User disconnected", { userId: disconnectedId });
    });
  } catch (err) {
    addLog("error", "Socket connection denied", { error: err.message });
    socket.emit("banned", { reason: err.message });
    socket.disconnect(true);
  }
});

adminNamespace.use(async (socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) {
    return next(new Error("Missing token"));
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded?.type !== "admin") {
      return next(new Error("Invalid token"));
    }
    if (await isTokenRevoked(decoded.jti)) {
      return next(new Error("Token revoked"));
    }
    socket.data.user = decoded;
    return next();
  } catch (err) {
    return next(new Error("Invalid token"));
  }
});

adminNamespace.on("connection", (socket) => {
  socket.emit("log:history", logBuffer);
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.get("/api/config", async (req, res) => {
  const maintenance = await getMaintenanceState();
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
});

app.get("/api/maintenance", async (req, res) => {
  const maintenance = await getMaintenanceState();
  res.json(maintenance);
});

app.post("/api/auth/anonymous", async (req, res) => {
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
    const token = jwt.sign(
      { sub: userId, type: "anonymous" },
      process.env.JWT_SECRET,
      { expiresIn: "30d", jwtid: uuidv4() }
    );
    addLog("info", "Anonymous user registered", { userId });
    return res.json({ userId, token });
  } catch (err) {
    addLog("error", "Anonymous auth error", { error: err.message });
    return res.status(500).json({ error: "Failed to register" });
  }
});

app.post("/api/report", ensureAuth, ensureNotBanned, async (req, res) => {
  const { reporterId, reportedId, reason } = req.body;
  if (!reporterId || !reportedId) {
    return res.status(400).json({ error: "Missing reporterId or reportedId" });
  }
  try {
    await pool.query(
      "INSERT INTO reports (reporter_id, reported_id, reason) VALUES ($1, $2, $3)",
      [reporterId, reportedId, reason || "unspecified"]
    );
    addLog("info", "Report submitted via API", { reporterId, reportedId });
    return res.json({ status: "ok" });
  } catch (err) {
    addLog("error", "Report API error", { error: err.message });
    return res.status(500).json({ error: "Failed to submit report" });
  }
});

app.post("/api/admin/login", async (req, res) => {
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
  const token = jwt.sign(
    { username, type: "admin" },
    process.env.JWT_SECRET,
    { expiresIn: "8h", jwtid: uuidv4() }
  );
  addLog("info", "Admin logged in", { username });
  return res.json({ token });
});

app.post("/api/admin/logout", ensureAuth, ensureAdmin, async (req, res) => {
  if (!req.user?.jti) {
    return res.status(400).json({ error: "Missing token id" });
  }
  await redisClient.sAdd("revoked_tokens", req.user.jti);
  return res.json({ status: "ok" });
});

app.get("/api/admin/stats", ensureAuth, ensureAdmin, async (req, res) => {
  try {
    const [reportCount, connectedUsers, waitingUsers] = await Promise.all([
      pool.query("SELECT COUNT(*) FROM reports"),
      redisClient.hLen("user_sockets"),
      redisClient.lLen("waiting_queue")
    ]);
    return res.json({
      connectedUsers: Number(connectedUsers || 0),
      waitingUsers: Number(waitingUsers || 0),
      reports: Number(reportCount.rows[0].count || 0)
    });
  } catch (err) {
    addLog("error", "Stats error", { error: err.message });
    return res.status(500).json({ error: "Failed to load stats" });
  }
});

app.get("/api/admin/reported", ensureAuth, ensureAdmin, async (req, res) => {
  try {
    const { rows } = await pool.query(
      "SELECT id, reporter_id, reported_id, reason, created_at FROM reports ORDER BY created_at DESC LIMIT 100"
    );
    return res.json({ reports: rows });
  } catch (err) {
    addLog("error", "Reported list error", { error: err.message });
    return res.status(500).json({ error: "Failed to load reports" });
  }
});

app.post("/api/admin/ban", ensureAuth, ensureAdmin, async (req, res) => {
  const { userId, reason } = req.body;
  if (!userId) {
    return res.status(400).json({ error: "Missing userId" });
  }
  try {
    await pool.query(
      "INSERT INTO bans (user_id, reason) VALUES ($1, $2)",
      [userId, reason || "admin"]
    );
    await redisClient.sAdd("banned_users", userId);
    const socketId = await getSocketForUser(userId);
    if (socketId) {
      io.to(socketId).emit("banned", { reason: reason || "admin" });
      io.in(socketId).disconnectSockets(true);
    }
    addLog("info", "User banned", { userId, reason });
    return res.json({ status: "ok" });
  } catch (err) {
    addLog("error", "Ban error", { error: err.message });
    return res.status(500).json({ error: "Failed to ban user" });
  }
});

app.post("/api/admin/maintenance", ensureAuth, ensureAdmin, async (req, res) => {
  const { enabled, message } = req.body || {};
  await setMaintenanceState({ enabled, message });
  const maintenance = await getMaintenanceState();
  addLog("info", "Maintenance mode updated", maintenance);
  return res.json(maintenance);
});

const startServer = async () => {
  try {
    await connectRedis();
    await ensureMaintenanceDefaults();
    const port = Number(process.env.PORT || 3000);
    server.listen(port, () => {
      addLog("info", "Backend listening", { port });
    });
  } catch (err) {
    console.error("Failed to start server", err);
    process.exit(1);
  }
};

startServer();

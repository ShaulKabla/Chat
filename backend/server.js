require("dotenv").config();
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
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

const limiter = rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 900000),
  max: Number(process.env.RATE_LIMIT_MAX || 200),
  standardHeaders: true,
  legacyHeaders: false
});

app.use(limiter);

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD
});

const redisClient = createClient({ url: process.env.REDIS_URL });
redisClient.on("error", (err) => console.error("Redis error", err));
redisClient.connect().catch((err) => console.error("Redis connect error", err));

const waitingQueue = [];
const socketToUser = new Map();
const userToSocket = new Map();
const pairedUsers = new Map();
const blockedUsers = new Map();

const logBuffer = [];
const logBufferSize = Number(process.env.LOG_BUFFER_SIZE || 200);

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

const ensureNotBanned = async (req, res, next) => {
  if (req.user?.sub && (await isBannedUser(req.user.sub))) {
    return res.status(403).json({ error: "User is banned" });
  }
  return next();
};

const removeFromQueue = (userId) => {
  const index = waitingQueue.indexOf(userId);
  if (index >= 0) {
    waitingQueue.splice(index, 1);
  }
  redisClient.sRem("waiting_queue", userId).catch(() => undefined);
};

const setPairing = (userA, userB) => {
  pairedUsers.set(userA, userB);
  pairedUsers.set(userB, userA);
  redisClient.hSet("pairings", userA, userB).catch(() => undefined);
  redisClient.hSet("pairings", userB, userA).catch(() => undefined);
};

const clearPairing = (userId) => {
  const partnerId = pairedUsers.get(userId);
  if (partnerId) {
    pairedUsers.delete(partnerId);
    redisClient.hDel("pairings", partnerId).catch(() => undefined);
  }
  pairedUsers.delete(userId);
  redisClient.hDel("pairings", userId).catch(() => undefined);
};

const isBlockedPair = (userA, userB) => {
  const blockedA = blockedUsers.get(userA) || new Set();
  const blockedB = blockedUsers.get(userB) || new Set();
  return blockedA.has(userB) || blockedB.has(userA);
};

const pairUsers = (userId) => {
  removeFromQueue(userId);
  let partnerId = null;
  for (let i = 0; i < waitingQueue.length; i += 1) {
    const candidate = waitingQueue[i];
    if (!isBlockedPair(userId, candidate)) {
      partnerId = candidate;
      waitingQueue.splice(i, 1);
      redisClient.sRem("waiting_queue", candidate).catch(() => undefined);
      break;
    }
  }

  if (!partnerId) {
    waitingQueue.push(userId);
    redisClient.sAdd("waiting_queue", userId).catch(() => undefined);
    return;
  }

  setPairing(userId, partnerId);
  const socketA = userToSocket.get(userId);
  const socketB = userToSocket.get(partnerId);
  if (socketA) {
    socketA.emit("paired", { partnerId });
  }
  if (socketB) {
    socketB.emit("paired", { partnerId: userId });
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
    const userId = await resolveUserId(socket);
    socketToUser.set(socket.id, userId);
    userToSocket.set(userId, socket);
    blockedUsers.set(userId, new Set());

    socket.emit("user:id", { userId });
    pairUsers(userId);
    addLog("info", "User connected", { userId });

    socket.on("chat:message", (payload) => {
      const partnerId = pairedUsers.get(userId);
      if (!partnerId) {
        return;
      }
      const partnerSocket = userToSocket.get(partnerId);
      if (!partnerSocket) {
        return;
      }
      partnerSocket.emit("chat:message", {
        from: userId,
        message: String(payload?.message || "")
      });
    });

    socket.on("user:block", (payload) => {
      const blockedId = String(payload?.blockedUserId || "");
      if (!blockedId) {
        return;
      }
      const blockSet = blockedUsers.get(userId) || new Set();
      blockSet.add(blockedId);
      blockedUsers.set(userId, blockSet);

      const partnerId = pairedUsers.get(userId);
      if (partnerId === blockedId) {
        clearPairing(userId);
        const partnerSocket = userToSocket.get(partnerId);
        if (partnerSocket) {
          partnerSocket.emit("partner:disconnected", { reason: "blocked" });
        }
        pairUsers(userId);
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

    socket.on("disconnect", () => {
      const disconnectedId = socketToUser.get(socket.id);
      if (!disconnectedId) {
        return;
      }
      socketToUser.delete(socket.id);
      userToSocket.delete(disconnectedId);
      blockedUsers.delete(disconnectedId);
      removeFromQueue(disconnectedId);

      const partnerId = pairedUsers.get(disconnectedId);
      if (partnerId) {
        clearPairing(disconnectedId);
        const partnerSocket = userToSocket.get(partnerId);
        if (partnerSocket) {
          partnerSocket.emit("partner:disconnected", { reason: "left" });
          pairUsers(partnerId);
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

app.get("/api/config", (req, res) => {
  res.json({
    version: process.env.APP_VERSION || "2.0.0",
    features: {
      reporting: true,
      blocking: true,
      notifications: true,
      logs: true
    }
  });
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

app.post("/api/admin/logout", ensureAuth, async (req, res) => {
  if (!req.user?.jti) {
    return res.status(400).json({ error: "Missing token id" });
  }
  await redisClient.sAdd("revoked_tokens", req.user.jti);
  return res.json({ status: "ok" });
});

app.get("/api/admin/stats", ensureAuth, async (req, res) => {
  try {
    const reportCount = await pool.query("SELECT COUNT(*) FROM reports");
    return res.json({
      connectedUsers: userToSocket.size,
      waitingUsers: waitingQueue.length,
      reports: Number(reportCount.rows[0].count || 0)
    });
  } catch (err) {
    addLog("error", "Stats error", { error: err.message });
    return res.status(500).json({ error: "Failed to load stats" });
  }
});

app.get("/api/admin/reported", ensureAuth, async (req, res) => {
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

app.post("/api/admin/ban", ensureAuth, async (req, res) => {
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
    const socket = userToSocket.get(userId);
    if (socket) {
      socket.emit("banned", { reason: reason || "admin" });
      socket.disconnect(true);
    }
    addLog("info", "User banned", { userId, reason });
    return res.json({ status: "ok" });
  } catch (err) {
    addLog("error", "Ban error", { error: err.message });
    return res.status(500).json({ error: "Failed to ban user" });
  }
});

const port = Number(process.env.PORT || 3000);
server.listen(port, () => {
  addLog("info", "Backend listening", { port });
});

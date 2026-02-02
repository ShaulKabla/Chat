require("dotenv").config();
const express = require("express");
const http = require("http");
const cors = require("cors");
const helmet = require("helmet");
const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const jwt = require("jsonwebtoken");

const { pool } = require("./services/postgres");
const { redisClient, pubClient, subClient, connectRedis } = require("./services/redis");
const { logger, containerId } = require("./services/logger");
const { addLog, logBuffer, setAdminNamespace } = require("./services/logStream");
const { ensureMaintenanceDefaults, getMaintenanceState } = require("./services/maintenance");
const {
  createGroup,
  enqueueMatchmaking,
  removeFromWaiting,
  clearPairing,
  isBlockedPair,
  startMatchmakingWorker
} = require("./services/matchmaking");
const { activeConnections, messagesTotal, observeRedisLatency } = require("./services/metrics");
const requestId = require("./middleware/requestId");
const requestLogger = require("./middleware/requestLogger");
const maintenanceGuard = require("./middleware/maintenanceGuard");
const { ensureAuth, ensureAdmin, ensureNotBanned, isTokenRevoked } = require("./middleware/auth");
const { createLimiter, socketLimiter } = require("./middleware/rateLimiters");
const { registerAnonymous } = require("./controllers/authController");
const {
  adminLogin,
  adminLogout,
  getStats,
  getReported,
  banUser,
  updateMaintenance
} = require("./controllers/adminController");
const { getConfig } = require("./controllers/configController");
const { submitReport } = require("./controllers/reportController");
const { getMaintenance } = require("./controllers/maintenanceController");
const { upload, handleUpload } = require("./controllers/uploadController");
const { health } = require("./controllers/healthController");
const { metrics } = require("./controllers/metricsController");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const adminNamespace = io.of("/admin");
setAdminNamespace(adminNamespace);

const drainState = { enabled: false };
const activeSockets = new Set();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestId);
app.use(requestLogger);
app.set("trust proxy", process.env.TRUST_PROXY || "loopback");
app.use("/api", maintenanceGuard(redisClient));

const adminLoginLimiter = createLimiter({
  redisClient,
  windowSeconds: Number(process.env.ADMIN_LOGIN_WINDOW_SEC || 600),
  max: Number(process.env.ADMIN_LOGIN_MAX || 5),
  prefix: "ratelimit:admin_login"
});

const uploadLimiter = createLimiter({
  redisClient,
  windowSeconds: Number(process.env.UPLOAD_WINDOW_SEC || 600),
  max: Number(process.env.UPLOAD_MAX || 10),
  prefix: "ratelimit:upload"
});

const chatRateLimit = {
  windowSeconds: Number(process.env.CHAT_WINDOW_SEC || 5),
  max: Number(process.env.CHAT_MAX || 20)
};

const initDb = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id SERIAL PRIMARY KEY,
      reporter_id TEXT NOT NULL,
      reported_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      image_url TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`ALTER TABLE reports ADD COLUMN IF NOT EXISTS image_url TEXT;`);
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

const setSocketForUser = async (userId, socketId) => {
  await redisClient.hSet("user_sockets", userId, socketId);
  await redisClient.hSet("socket_users", socketId, userId);
};

const removeSocket = async (socketId) => {
  const userId = await redisClient.hGet("socket_users", socketId);
  if (!userId) return null;
  await redisClient.hDel("socket_users", socketId);
  await redisClient.hDel("user_sockets", userId);
  return userId;
};

const resolveUserId = async (socket) => {
  const token = socket.handshake.auth?.token;
  if (!token) {
    return null;
  }
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  if (await isTokenRevoked(redisClient, decoded.jti)) {
    throw new Error("Token revoked");
  }
  if (await redisClient.sIsMember("banned_users", decoded.sub)) {
    throw new Error("User banned");
  }
  return decoded.sub;
};

const getBackendInstanceCount = async () => {
  const adapter = io.of("/").adapter;
  if (adapter && typeof adapter.serverCount === "function") {
    return adapter.serverCount();
  }
  return 1;
};

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
    if (await isTokenRevoked(redisClient, decoded.jti)) {
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

io.on("connection", async (socket) => {
  const requestIdValue = socket.id;
  activeSockets.add(socket.id);
  activeConnections.inc();
  try {
    const maintenance = await getMaintenanceState(redisClient);
    if (maintenance.enabled) {
      socket.emit("maintenance", { message: maintenance.message });
      socket.disconnect(true);
      return;
    }

    const userId = await resolveUserId(socket);
    if (!userId) {
      socket.emit("auth:error", { error: "Missing token" });
      socket.disconnect(true);
      return;
    }
    await setSocketForUser(userId, socket.id);

    socket.emit("user:id", { userId });
    if (!drainState.enabled) {
      await enqueueMatchmaking(redisClient, userId);
    }
    addLog("info", "User connected", { userId, requestId: requestIdValue });

    socket.on("chat:message", async (payload) => {
      const allowed = await socketLimiter(
        redisClient,
        `ratelimit:chat:${userId}`,
        chatRateLimit.windowSeconds,
        chatRateLimit.max
      );
      if (!allowed) {
        socket.emit("rate_limit", { scope: "chat" });
        return;
      }

      const partnerId = await redisClient.hGet("pairings", userId);
      if (!partnerId) {
        return;
      }
      const partnerSocketId = await redisClient.hGet("user_sockets", partnerId);
      if (!partnerSocketId) {
        return;
      }
      io.to(partnerSocketId).emit("chat:message", {
        from: userId,
        message: String(payload?.message || "")
      });
      messagesTotal.inc();
    });

    socket.on("user:block", async (payload) => {
      const blockedId = String(payload?.blockedUserId || "");
      if (!blockedId) {
        return;
      }
      await redisClient.sAdd(`blocked:${userId}`, blockedId);

      const partnerId = await redisClient.hGet("pairings", userId);
      if (partnerId === blockedId) {
        await clearPairing(redisClient, userId);
        const partnerSocketId = await redisClient.hGet("user_sockets", partnerId);
        if (partnerSocketId) {
          io.to(partnerSocketId).emit("partner:disconnected", { reason: "blocked" });
        }
        if (!drainState.enabled) {
          await enqueueMatchmaking(redisClient, userId);
        }
      }
    });

    socket.on("user:report", async (payload) => {
      const reportedId = String(payload?.reportedUserId || "");
      const reason = String(payload?.reason || "unspecified");
      const imageUrl = payload?.imageUrl ? String(payload.imageUrl) : null;
      if (!reportedId) {
        return;
      }
      try {
        await pool.query(
          "INSERT INTO reports (reporter_id, reported_id, reason, image_url) VALUES ($1, $2, $3, $4)",
          [userId, reportedId, reason, imageUrl]
        );
        socket.emit("report:received", { status: "ok" });
        addLog("info", "User reported", {
          reporterId: userId,
          reportedId,
          reason,
          imageUrl,
          requestId: requestIdValue
        });
      } catch (err) {
        addLog("error", "Report error", { error: err.message, requestId: requestIdValue });
        socket.emit("report:received", { status: "error" });
      }
    });

    socket.on("disconnect", async () => {
      activeSockets.delete(socket.id);
      activeConnections.dec();
      const disconnectedId = await removeSocket(socket.id);
      if (!disconnectedId) {
        return;
      }
      await redisClient.del(`blocked:${disconnectedId}`);
      await removeFromWaiting(redisClient, disconnectedId);

      const partnerId = await clearPairing(redisClient, disconnectedId);
      if (partnerId) {
        const partnerSocketId = await redisClient.hGet("user_sockets", partnerId);
        if (partnerSocketId) {
          io.to(partnerSocketId).emit("partner:disconnected", { reason: "left" });
          if (!drainState.enabled) {
            await enqueueMatchmaking(redisClient, partnerId);
          }
        }
      }
      addLog("info", "User disconnected", {
        userId: disconnectedId,
        requestId: requestIdValue
      });
    });
  } catch (err) {
    addLog("error", "Socket connection denied", { error: err.message, requestId: requestIdValue });
    socket.emit("banned", { reason: err.message });
    socket.disconnect(true);
  }
});

app.get("/health", health);
app.get("/internal/metrics", metrics);
app.get("/api/config", getConfig(redisClient));
app.get("/api/maintenance", getMaintenance(redisClient));
app.post("/api/auth/anonymous", registerAnonymous(pool, redisClient));
app.post(
  "/api/report",
  ensureAuth(redisClient),
  ensureNotBanned(redisClient),
  submitReport(pool)
);
app.post(
  "/api/uploads/report",
  ensureAuth(redisClient),
  ensureNotBanned(redisClient),
  uploadLimiter,
  upload.single("image"),
  handleUpload
);
app.post("/api/admin/login", adminLoginLimiter, adminLogin(redisClient));
app.post("/api/admin/logout", ensureAuth(redisClient), ensureAdmin, adminLogout(redisClient));
app.get(
  "/api/admin/stats",
  ensureAuth(redisClient),
  ensureAdmin,
  getStats(pool, redisClient, getBackendInstanceCount)
);
app.get(
  "/api/admin/reported",
  ensureAuth(redisClient),
  ensureAdmin,
  getReported(pool)
);
app.post(
  "/api/admin/ban",
  ensureAuth(redisClient),
  ensureAdmin,
  banUser(pool, redisClient, io)
);
app.post(
  "/api/admin/maintenance",
  ensureAuth(redisClient),
  ensureAdmin,
  updateMaintenance(redisClient)
);

const startServer = async () => {
  try {
    await connectRedis();
    io.adapter(createAdapter(pubClient, subClient));
    await ensureMaintenanceDefaults(redisClient);
    await initDb();
    await createGroup(redisClient);
    startMatchmakingWorker({ redisClient, io, drainState, containerId });

    setInterval(() => {
      observeRedisLatency(redisClient).catch(() => {});
    }, 10000);

    const port = Number(process.env.PORT || 3000);
    server.listen(port, () => {
      logger.info({ requestId: "startup", containerId, port }, "Backend listening");
    });
  } catch (err) {
    logger.error({ err }, "Failed to start server");
    process.exit(1);
  }
};

process.on("SIGTERM", () => {
  if (drainState.enabled) {
    return;
  }
  drainState.enabled = true;
  addLog("info", "Drain mode enabled", { requestId: "system" });
  setTimeout(() => {
    for (const socketId of activeSockets) {
      io.to(socketId).disconnectSockets(true);
    }
  }, 60000);
});

startServer();

require("dotenv").config();
const express = require("express");
const http = require("http");
const cors = require("cors");
const helmet = require("helmet");
const path = require("path");
const fs = require("fs/promises");
const { Server } = require("socket.io");
const { randomUUID } = require("crypto");
const jwt = require("jsonwebtoken");

const { pool } = require("./services/postgres");
const { redisClient, connectRedis } = require("./services/redis");
const { logger, containerId } = require("./services/logger");
const { addLog, logBuffer, setAdminNamespace } = require("./services/logStream");
const { ensureMaintenanceDefaults, getMaintenanceState } = require("./services/maintenance");
const {
  enqueueMatchmaking,
  removeFromQueue,
  getQueueCandidates,
  getQueueScore,
  QUEUE_KEY_TALK,
  QUEUE_KEY_MEET
} = require("./services/matchmaking");
const { initI18n, i18nMiddleware, getSocketTranslator } = require("./services/i18n");
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
  updateMaintenance,
  getSystemSnapshot
} = require("./controllers/adminController");
const { getConfig } = require("./controllers/configController");
const { submitReport } = require("./controllers/reportController");
const { getMaintenance } = require("./controllers/maintenanceController");
const { upload, handleUpload } = require("./controllers/uploadController");
const { health } = require("./controllers/healthController");
const { getProfile, upsertProfile } = require("./controllers/profileController");
const {
  getFriends,
  getFriendMessages,
  sendFriendMessage
} = require("./controllers/friendsController");

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

const socketByUser = new Map();
const userBySocket = new Map();
const pairings = new Map();
const matchingLocks = new Set();
const skipLocks = new Set();
const sessions = new Map();
const sessionByUser = new Map();
const userModes = new Map();
const expandedSearchNotified = new Map();
const mediaCleanupStatus = {
  lastRunAt: null,
  lastSuccessAt: null,
  lastError: null,
  lastResult: null
};

const uploadsDir = process.env.UPLOADS_DIR || path.resolve(__dirname, "../uploads");
const revealDelayMs = Number(process.env.REVEAL_DELAY_MS || 7 * 60 * 1000);
const revealTickMs = Number(process.env.REVEAL_TICK_MS || 1000);
const meetExpandDelayMs = Number(process.env.MEET_EXPAND_DELAY_MS || 15000);
const mediaRetentionDays = Number(process.env.MEDIA_RETENTION_DAYS || 5);

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestId);
app.use(requestLogger);
app.use(i18nMiddleware);
app.set("trust proxy", process.env.TRUST_PROXY || "loopback");
app.use("/api", maintenanceGuard(redisClient));
app.use("/uploads", express.static(uploadsDir));

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
  windowSeconds: Number(process.env.CHAT_WINDOW_SEC || 1),
  max: Number(process.env.CHAT_MAX || 5)
};

const skipRateLimit = {
  windowSeconds: Number(process.env.SKIP_WINDOW_SEC || 300),
  max: Number(process.env.SKIP_MAX || 10)
};

const connectRateLimit = {
  windowSeconds: Number(process.env.CONNECT_WINDOW_SEC || 60),
  max: Number(process.env.CONNECT_MAX || 4)
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
  await pool.query(`CREATE INDEX IF NOT EXISTS reports_created_at_idx ON reports (created_at);`);
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
  await pool.query(`
    CREATE TABLE IF NOT EXISTS profiles (
      user_id TEXT PRIMARY KEY,
      gender TEXT NOT NULL,
      age_group TEXT NOT NULL,
      interests TEXT[] NOT NULL,
      gender_preference TEXT NOT NULL DEFAULT 'any',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS blocks (
      blocker_id TEXT NOT NULL,
      blocked_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (blocker_id, blocked_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friends (
      user_id TEXT NOT NULL,
      friend_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (user_id, friend_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friend_requests (
      requester_id TEXT NOT NULL,
      addressee_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (requester_id, addressee_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friend_messages (
      id SERIAL PRIMARY KEY,
      sender_id TEXT NOT NULL,
      recipient_id TEXT NOT NULL,
      body TEXT,
      image_url TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS friend_messages_created_at_idx ON friend_messages (created_at);`);
};

const setSocketForUser = (userId, socketId) => {
  socketByUser.set(userId, socketId);
  userBySocket.set(socketId, userId);
};

const removeSocket = (socketId) => {
  const userId = userBySocket.get(socketId);
  if (!userId) return null;
  userBySocket.delete(socketId);
  socketByUser.delete(userId);
  return userId;
};

const resolveUserId = async (socket) => {
  const token = socket.handshake.auth?.token;
  if (!token) {
    return null;
  }
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  if (await isTokenRevoked(redisClient, decoded.jti)) {
    throw new Error("token_revoked");
  }
  if (await redisClient.sIsMember("banned_users", decoded.sub)) {
    throw new Error("account_banned");
  }
  return decoded.sub;
};

const fetchProfile = async (userId) => {
  const { rows } = await pool.query(
    "SELECT user_id, gender, age_group, interests, gender_preference FROM profiles WHERE user_id = $1",
    [userId]
  );
  return rows[0] || null;
};

const upsertProfileForSocket = async (userId, payload) => {
  const { gender, ageGroup, interests, genderPreference } = payload || {};
  if (!gender || !ageGroup || !Array.isArray(interests) || interests.length < 3) {
    return { error: "errors.missingProfile" };
  }
  const sanitizedInterests = interests.map((item) => String(item).trim()).filter(Boolean);
  if (sanitizedInterests.length < 3) {
    return { error: "errors.missingProfile" };
  }

  const { rows } = await pool.query(
    `
      INSERT INTO profiles (user_id, gender, age_group, interests, gender_preference)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (user_id)
      DO UPDATE SET gender = $2, age_group = $3, interests = $4, gender_preference = $5, updated_at = NOW()
      RETURNING user_id, gender, age_group, interests, gender_preference
    `,
    [userId, gender, ageGroup, sanitizedInterests, genderPreference || "any"]
  );
  return { profile: rows[0] };
};

const areGenderCompatible = (profileA, profileB) => {
  const prefA = profileA.gender_preference || "any";
  const prefB = profileB.gender_preference || "any";
  if (prefA !== "any" && prefA !== profileB.gender) {
    return false;
  }
  if (prefB !== "any" && prefB !== profileA.gender) {
    return false;
  }
  return true;
};

const sharedInterestCount = (profileA, profileB) => {
  const setA = new Set(profileA.interests || []);
  return (profileB.interests || []).filter((interest) => setA.has(interest)).length;
};

const getBlockedCandidates = async (userId, candidateIds) => {
  if (!candidateIds.length) {
    return new Set();
  }
  const { rows } = await pool.query(
    `
      SELECT blocker_id, blocked_id
      FROM blocks
      WHERE (blocker_id = $1 AND blocked_id = ANY($2))
         OR (blocked_id = $1 AND blocker_id = ANY($2))
    `,
    [userId, candidateIds]
  );
  const blocked = new Set();
  rows.forEach((row) => {
    if (row.blocker_id === userId) {
      blocked.add(row.blocked_id);
    } else {
      blocked.add(row.blocker_id);
    }
  });
  return blocked;
};

const queueKeyForMode = (mode) => (mode === "meet" ? QUEUE_KEY_MEET : QUEUE_KEY_TALK);

const getSocketForUser = (userId) => {
  const socketId = socketByUser.get(userId);
  if (!socketId) {
    return null;
  }
  return io.sockets.sockets.get(socketId) || null;
};

const getTranslatorForUser = (userId) => {
  const socket = getSocketForUser(userId);
  return socket?.data?.t || ((key) => key);
};

const createSession = (userId, partnerId, mode) => {
  const key = [userId, partnerId].sort().join(":");
  const session = {
    key,
    users: [userId, partnerId],
    mode,
    revealAvailable: false,
    revealGranted: false,
    revealAt: null,
    revealTimer: null,
    revealRequests: new Set(),
    connectRequests: new Set(),
    chatters: new Set(),
    pendingImages: new Map()
  };
  sessions.set(key, session);
  sessionByUser.set(userId, key);
  sessionByUser.set(partnerId, key);
  return session;
};

const clearSession = (userId) => {
  const key = sessionByUser.get(userId);
  if (!key) {
    return;
  }
  const session = sessions.get(key);
  if (session?.revealTimer) {
    clearInterval(session.revealTimer);
    addLog("info", "Reveal timer cleared", { sessionKey: key });
  }
  session?.pendingImages?.clear?.();
  if (session?.users) {
    session.users.forEach((id) => sessionByUser.delete(id));
  }
  sessions.delete(key);
  addLog("info", "Session cleared", { sessionKey: key });
};

const startRevealTimer = (session) => {
  if (session.revealTimer || session.revealAvailable || session.mode !== "meet") {
    return;
  }
  session.revealAt = Date.now() + revealDelayMs;
  session.users.forEach((userId) => {
    const socket = getSocketForUser(userId);
    if (socket) {
      socket.emit("reveal_timer_started", { revealAt: session.revealAt, durationMs: revealDelayMs });
    }
  });
  session.revealTimer = setInterval(() => {
    if (session.revealAvailable || !session.revealAt) {
      return;
    }
    if (Date.now() >= session.revealAt) {
      session.revealAvailable = true;
      session.revealAt = null;
      if (session.revealTimer) {
        clearInterval(session.revealTimer);
        session.revealTimer = null;
      }
      session.users.forEach((userId) => {
        const socket = getSocketForUser(userId);
        if (socket) {
          socket.emit("reveal_available");
        }
      });
    }
  }, revealTickMs);
};

const matchUsers = async (userId, mode) => {
  if (matchingLocks.has(userId)) {
    return;
  }
  matchingLocks.add(userId);
  let candidateLocked = null;
  try {
    if (pairings.has(userId)) {
      return;
    }
    const queueKey = queueKeyForMode(mode);
    const queueCandidates = await getQueueCandidates(redisClient, 50, queueKey);
    const candidateIds = queueCandidates
      .map((entry) => entry.value)
      .filter((candidateId) => candidateId !== userId && !pairings.has(candidateId));
    if (!candidateIds.length) {
      return;
    }

    const blocked = await getBlockedCandidates(userId, candidateIds);
    const queueOrder = new Map(queueCandidates.map((entry, index) => [entry.value, index]));
    const queueScores = new Map(queueCandidates.map((entry) => [entry.value, Number(entry.score)]));

    let bestCandidate = null;
    let bestScore = -1;
    let bestOrder = Number.POSITIVE_INFINITY;

    if (mode === "meet") {
      const profile = await fetchProfile(userId);
      if (!profile) {
        const socketId = socketByUser.get(userId);
        if (socketId) {
          io.to(socketId).emit("profile_required", {
            message: getTranslatorForUser(userId)("errors.missingProfile")
          });
        }
        return;
      }

      const userScore = await getQueueScore(redisClient, userId, queueKey);
      const isExpanded = userScore ? Date.now() - userScore >= meetExpandDelayMs : false;
      if (isExpanded && !expandedSearchNotified.get(userId)) {
        const socketId = socketByUser.get(userId);
        if (socketId) {
          io.to(socketId).emit("search_expanding", {
            message: getTranslatorForUser(userId)("match.expanding")
          });
          expandedSearchNotified.set(userId, true);
        }
      }

      const profilesResult = await pool.query(
        "SELECT user_id, gender, age_group, interests, gender_preference FROM profiles WHERE user_id = ANY($1)",
        [[userId, ...candidateIds]]
      );
      const profiles = new Map();
      profilesResult.rows.forEach((row) => profiles.set(row.user_id, row));
      const userProfile = profiles.get(userId);
      if (!userProfile) {
        return;
      }

      candidateIds.forEach((candidateId) => {
        if (blocked.has(candidateId)) {
          return;
        }
        const candidateProfile = profiles.get(candidateId);
        if (!candidateProfile) {
          return;
        }
        if (!areGenderCompatible(userProfile, candidateProfile)) {
          return;
        }
        const score = sharedInterestCount(userProfile, candidateProfile);
        if (score === 0 && !isExpanded) {
          return;
        }
        const order = queueOrder.get(candidateId) ?? Number.POSITIVE_INFINITY;
        if (score > bestScore || (score === bestScore && order < bestOrder)) {
          bestScore = score;
          bestOrder = order;
          bestCandidate = candidateId;
        }
      });
    } else {
      candidateIds.forEach((candidateId) => {
        if (blocked.has(candidateId)) {
          return;
        }
        const score = queueScores.get(candidateId) ?? Number.POSITIVE_INFINITY;
        if (score < bestScore || bestScore === -1) {
          bestScore = score;
          bestCandidate = candidateId;
        }
      });
    }

    if (!bestCandidate) {
      return;
    }
    if (matchingLocks.has(bestCandidate)) {
      return;
    }
    matchingLocks.add(bestCandidate);
    candidateLocked = bestCandidate;

    await removeFromQueue(redisClient, userId, queueKey);
    await removeFromQueue(redisClient, bestCandidate, queueKey);
    pairings.set(userId, bestCandidate);
    pairings.set(bestCandidate, userId);
    expandedSearchNotified.delete(userId);
    expandedSearchNotified.delete(bestCandidate);
    const session = createSession(userId, bestCandidate, mode);

    let partnerProfile = null;
    let userProfile = null;
    if (mode === "meet") {
      userProfile = await fetchProfile(userId);
      partnerProfile = await fetchProfile(bestCandidate);
    }
    const socketA = socketByUser.get(userId);
    const socketB = socketByUser.get(bestCandidate);
    if (socketA) {
      io.to(socketA).emit("match_found", {
        partnerId: bestCandidate,
        mode: session.mode,
        revealAvailable: session.revealAvailable,
        partnerProfile: partnerProfile
          ? {
              gender: partnerProfile.gender,
              ageGroup: partnerProfile.age_group,
              interests: partnerProfile.interests
            }
          : null
      });
    }
    if (socketB) {
      io.to(socketB).emit("match_found", {
        partnerId: userId,
        mode: session.mode,
        revealAvailable: session.revealAvailable,
        partnerProfile: userProfile
          ? {
              gender: userProfile.gender,
              ageGroup: userProfile.age_group,
              interests: userProfile.interests
            }
          : null
      });
    }
    addLog("info", "Users paired", { userId, partnerId: bestCandidate });
  } finally {
    matchingLocks.delete(userId);
    if (candidateLocked) {
      matchingLocks.delete(candidateLocked);
    }
  }
};

const handleSkip = async (userId, reason = "skipped") => {
  if (skipLocks.has(userId)) {
    return;
  }
  skipLocks.add(userId);
  let partnerLocked = null;
  try {
    const partnerId = pairings.get(userId);
    if (!partnerId) {
      return;
    }
    if (skipLocks.has(partnerId)) {
      return;
    }
    skipLocks.add(partnerId);
    partnerLocked = partnerId;

    const sessionKey = sessionByUser.get(userId);
    const session = sessionKey ? sessions.get(sessionKey) : null;
    const mode = session?.mode || userModes.get(userId) || "talk";
    pairings.delete(userId);
    pairings.delete(partnerId);
    clearSession(userId);
    expandedSearchNotified.delete(userId);
    expandedSearchNotified.delete(partnerId);

    const partnerSocketId = socketByUser.get(partnerId);
    const userSocketId = socketByUser.get(userId);
    const partnerTranslator = getTranslatorForUser(partnerId);
    const userTranslator = getTranslatorForUser(userId);

    if (partnerSocketId) {
      io.to(partnerSocketId).emit("partner_left", {
        reason,
        systemMessage: partnerTranslator("match.partnerLeft")
      });
      io.to(partnerSocketId).emit("match_searching", {
        message: partnerTranslator("match.searching")
      });
    }
    if (userSocketId) {
      io.to(userSocketId).emit("match_searching", {
        message: userTranslator("match.searching")
      });
    }

    await removeFromQueue(redisClient, userId, queueKeyForMode(mode));
    await removeFromQueue(redisClient, partnerId, queueKeyForMode(mode));
    await enqueueMatchmaking(redisClient, userId, queueKeyForMode(mode));
    await enqueueMatchmaking(redisClient, partnerId, queueKeyForMode(mode));
    await Promise.all([matchUsers(userId, mode), matchUsers(partnerId, mode)]);
  } finally {
    skipLocks.delete(userId);
    if (partnerLocked) {
      skipLocks.delete(partnerLocked);
    }
  }
};

const createFriendship = async (userId, partnerId) => {
  await pool.query(
    "INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
    [userId, partnerId]
  );
  await pool.query(
    "INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
    [partnerId, userId]
  );
  await pool.query(
    "DELETE FROM friend_requests WHERE (requester_id = $1 AND addressee_id = $2) OR (requester_id = $2 AND addressee_id = $1)",
    [userId, partnerId]
  );
};

const resolveUploadPath = (imageUrl) => {
  if (!imageUrl) {
    return null;
  }
  try {
    const parsed = imageUrl.startsWith("http")
      ? new URL(imageUrl).pathname
      : imageUrl;
    if (!parsed.startsWith("/uploads")) {
      return null;
    }
    const relativePath = parsed.replace(/^\/uploads\/?/, "");
    return path.join(uploadsDir, relativePath);
  } catch (err) {
    return null;
  }
};

const cleanupOldMedia = async () => {
  mediaCleanupStatus.lastRunAt = Date.now();
  const cutoff = new Date(Date.now() - mediaRetentionDays * 24 * 60 * 60 * 1000);
  try {
    const reportResult = await pool.query(
      "UPDATE reports SET image_url = NULL WHERE image_url IS NOT NULL AND created_at < $1 RETURNING id, image_url",
      [cutoff]
    );
    const messageResult = await pool.query(
      "UPDATE friend_messages SET image_url = NULL WHERE image_url IS NOT NULL AND created_at < $1 RETURNING id, image_url",
      [cutoff]
    );

    const deleteFiles = async (rows) => {
      await Promise.all(
        rows.map(async (row) => {
          const filePath = resolveUploadPath(row.image_url);
          if (filePath) {
            await fs.unlink(filePath).catch(() => {});
          }
        })
      );
    };

    await deleteFiles(reportResult.rows);
    await deleteFiles(messageResult.rows);
    mediaCleanupStatus.lastSuccessAt = Date.now();
    mediaCleanupStatus.lastError = null;
    mediaCleanupStatus.lastResult = {
      reports: reportResult.rows.length,
      messages: messageResult.rows.length
    };
    addLog("info", "Media cleanup complete", {
      reports: reportResult.rows.length,
      messages: messageResult.rows.length
    });
  } catch (err) {
    mediaCleanupStatus.lastError = err.message;
    throw err;
  }
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
  try {
    const maintenance = await getMaintenanceState(redisClient);
    if (maintenance.enabled) {
      socket.emit("maintenance_mode", { enabled: true, message: maintenance.message });
      socket.disconnect(true);
      return;
    }

    const t = getSocketTranslator(socket);
    socket.data.t = t;

    const userId = await resolveUserId(socket);
    if (!userId) {
      socket.emit("auth_error", { message: t("errors.missingToken") });
      socket.disconnect(true);
      return;
    }
    setSocketForUser(userId, socket.id);

    socket.emit("user:id", { userId });
    addLog("info", "User connected", { userId, requestId: requestIdValue });

    socket.on("find_match", async (payload) => {
      if (await redisClient.sIsMember("banned_users", userId)) {
        socket.emit("banned", { message: t("errors.accountBanned") });
        return;
      }
      const mode = payload?.mode === "meet" ? "meet" : "talk";
      userModes.set(userId, mode);
      expandedSearchNotified.delete(userId);
      await removeFromQueue(redisClient, userId, QUEUE_KEY_TALK);
      await removeFromQueue(redisClient, userId, QUEUE_KEY_MEET);

      if (mode === "meet") {
        const profile = await fetchProfile(userId);
        if (!profile) {
          socket.emit("profile_required", { message: t("errors.missingProfile") });
          return;
        }
      }

      await enqueueMatchmaking(redisClient, userId, queueKeyForMode(mode));
      await matchUsers(userId, mode);
    });

    socket.on("skip", async () => {
      const allowed = await socketLimiter(
        redisClient,
        `ratelimit:skip:${userId}`,
        skipRateLimit.windowSeconds,
        skipRateLimit.max
      );
      if (!allowed) {
        socket.emit("rate_limit", { scope: "skip" });
        socket.emit("rate_limit_reached", { scope: "skip" });
        return;
      }
      await handleSkip(userId, "skipped");
    });

    socket.on("message", async (payload, ack) => {
      const allowed = await socketLimiter(
        redisClient,
        `ratelimit:chat:${userId}`,
        chatRateLimit.windowSeconds,
        chatRateLimit.max
      );
      if (!allowed) {
        socket.emit("rate_limit", { scope: "chat" });
        socket.emit("rate_limit_reached", { scope: "chat" });
        socket.emit("message_ack", {
          ok: false,
          clientId: payload?.clientId,
          error: "rate_limited"
        });
        if (typeof ack === "function") {
          ack({ ok: false, error: "rate_limited" });
        }
        return;
      }

      const partnerId = pairings.get(userId);
      if (!partnerId) {
        if (typeof ack === "function") {
          ack({ ok: false, error: "no_partner" });
        }
        return;
      }
      const partnerSocketId = socketByUser.get(partnerId);
      if (!partnerSocketId) {
        if (typeof ack === "function") {
          ack({ ok: false, error: "partner_offline" });
        }
        return;
      }
      const messageId = randomUUID();
      const sessionKey = sessionByUser.get(userId);
      const session = sessionKey ? sessions.get(sessionKey) : null;
      const isMeetSession = session?.mode === "meet";
      const imagePreview = payload?.imagePreview || payload?.image || null;
      const imageSource = payload?.imageSource || payload?.image || null;
      const shouldHideImage = Boolean(imageSource && isMeetSession && !session?.revealGranted);

      if (shouldHideImage && session) {
        session.pendingImages.set(messageId, {
          imageUrl: imageSource,
          senderId: userId
        });
      }

      const outgoing = {
        id: messageId,
        clientId: payload?.clientId,
        text: String(payload?.text || ""),
        createdAt: payload?.createdAt || Date.now(),
        userId,
        image: shouldHideImage ? imagePreview : imageSource,
        imagePending: shouldHideImage,
        replyTo: payload?.replyTo
      };
      io.to(partnerSocketId).emit("message", outgoing);

      if (isMeetSession) {
        session.chatters.add(userId);
        if (session.chatters.size >= 2) {
          startRevealTimer(session);
        }
      }
      socket.emit("message_ack", {
        ok: true,
        clientId: payload?.clientId,
        messageId,
        status: "delivered"
      });
      if (typeof ack === "function") {
        ack({ ok: true, messageId });
      }
    });

    socket.on("typing", async () => {
      const partnerId = pairings.get(userId);
      const partnerSocketId = partnerId ? socketByUser.get(partnerId) : null;
      if (partnerSocketId) {
        io.to(partnerSocketId).emit("typing", { userId });
      }
    });

    socket.on("stop_typing", async () => {
      const partnerId = pairings.get(userId);
      const partnerSocketId = partnerId ? socketByUser.get(partnerId) : null;
      if (partnerSocketId) {
        io.to(partnerSocketId).emit("stop_typing", { userId });
      }
    });

    socket.on("ping", (payload) => {
      socket.emit("pong", { ts: payload?.ts ?? Date.now() });
    });

    socket.on("block_user", async (payload) => {
      const blockedId = String(payload?.blockedUserId || "");
      if (!blockedId) {
        return;
      }
      await pool.query(
        "INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        [userId, blockedId]
      );
      if (pairings.get(userId) === blockedId) {
        await handleSkip(userId, "blocked");
      }
    });

    socket.on("update_profile", async (payload, ack) => {
      try {
        const result = await upsertProfileForSocket(userId, payload);
        if (result.error) {
          const message = t(result.error);
          socket.emit("profile_required", { message });
          if (typeof ack === "function") {
            ack({ ok: false, error: result.error });
          }
          return;
        }
        if (typeof ack === "function") {
          ack({ ok: true, profile: result.profile });
        }
      } catch (err) {
        const message = t("errors.failedProfileSave");
        socket.emit("profile_required", { message });
        if (typeof ack === "function") {
          ack({ ok: false, error: "errors.failedProfileSave" });
        }
      }
    });

    socket.on("reveal_request", async () => {
      const sessionKey = sessionByUser.get(userId);
      const session = sessionKey ? sessions.get(sessionKey) : null;
      if (!session || session.mode !== "meet" || !session.revealAvailable) {
        return;
      }
      session.revealRequests.add(userId);
      if (session.revealRequests.size >= 2) {
        session.revealGranted = true;
        session.users.forEach((participantId) => {
          const participantSocketId = socketByUser.get(participantId);
          if (participantSocketId) {
            io.to(participantSocketId).emit("reveal_confirmed");
          }
        });
        if (session.pendingImages.size > 0) {
          const images = Array.from(session.pendingImages.entries()).map(([messageId, entry]) => ({
            messageId,
            imageUrl: entry.imageUrl
          }));
          session.pendingImages.clear();
          session.users.forEach((participantId) => {
            const participantSocketId = socketByUser.get(participantId);
            if (participantSocketId) {
              io.to(participantSocketId).emit("source_revealed", { images });
            }
          });
        }
        session.users.forEach((participantId) => {
          const participantSocketId = socketByUser.get(participantId);
          if (participantSocketId) {
            io.to(participantSocketId).emit("reveal_granted");
          }
        });
      }
    });

    socket.on("connect_request", async () => {
      const allowed = await socketLimiter(
        redisClient,
        `ratelimit:connect:${userId}`,
        connectRateLimit.windowSeconds,
        connectRateLimit.max
      );
      if (!allowed) {
        socket.emit("rate_limit", { scope: "connect" });
        socket.emit("rate_limit_reached", { scope: "connect" });
        return;
      }
      const partnerId = pairings.get(userId);
      if (!partnerId) {
        return;
      }
      const sessionKey = sessionByUser.get(userId);
      const session = sessionKey ? sessions.get(sessionKey) : null;
      if (!session) {
        return;
      }
      const { rows: existingFriend } = await pool.query(
        "SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2",
        [userId, partnerId]
      );
      if (existingFriend.length) {
        socket.emit("friend_added", { friendId: partnerId });
        return;
      }

      session.connectRequests.add(userId);
      if (session.connectRequests.has(partnerId)) {
        await createFriendship(userId, partnerId);
        session.users.forEach((participantId) => {
          const participantSocketId = socketByUser.get(participantId);
          if (participantSocketId) {
            io.to(participantSocketId).emit("friend_added", { friendId: participantId === userId ? partnerId : userId });
          }
        });
        return;
      }

      const partnerSocketId = socketByUser.get(partnerId);
      if (partnerSocketId) {
        io.to(partnerSocketId).emit("connect_request", { userId });
      }
    });

    socket.on("friend_message", async (payload, ack) => {
      const friendId = String(payload?.friendId || "");
      if (!friendId) {
        return;
      }
      const body = payload?.text ? String(payload.text) : "";
      const imageUrl = payload?.image ? String(payload.image) : null;
      const { rows: exists } = await pool.query(
        "SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2",
        [userId, friendId]
      );
      if (!exists.length) {
        if (typeof ack === "function") {
          ack({ ok: false, error: "not_friends" });
        }
        return;
      }

      const { rows } = await pool.query(
        "INSERT INTO friend_messages (sender_id, recipient_id, body, image_url) VALUES ($1, $2, $3, $4) RETURNING id, created_at",
        [userId, friendId, body, imageUrl]
      );
      const message = {
        id: rows[0].id,
        senderId: userId,
        recipientId: friendId,
        body,
        imageUrl,
        createdAt: rows[0].created_at
      };
      const friendSocketId = socketByUser.get(friendId);
      if (friendSocketId) {
        io.to(friendSocketId).emit("friend_message", message);
      }
      if (typeof ack === "function") {
        ack({ ok: true, messageId: rows[0].id });
      }
    });

    socket.on("disconnect", async () => {
      const disconnectedId = removeSocket(socket.id);
      if (!disconnectedId) {
        return;
      }
      userModes.delete(disconnectedId);
      expandedSearchNotified.delete(disconnectedId);
      await removeFromQueue(redisClient, disconnectedId, QUEUE_KEY_TALK);
      await removeFromQueue(redisClient, disconnectedId, QUEUE_KEY_MEET);

      const partnerId = pairings.get(disconnectedId);
      if (partnerId) {
        const sessionKey = sessionByUser.get(disconnectedId);
        const session = sessionKey ? sessions.get(sessionKey) : null;
        const mode = session?.mode || userModes.get(partnerId) || "talk";
        pairings.delete(disconnectedId);
        pairings.delete(partnerId);
        clearSession(disconnectedId);
        expandedSearchNotified.delete(partnerId);
        const partnerSocketId = socketByUser.get(partnerId);
        if (partnerSocketId) {
          io.to(partnerSocketId).emit("partner_left", {
            reason: "left",
            systemMessage: getTranslatorForUser(partnerId)("match.partnerLeft")
          });
          io.to(partnerSocketId).emit("match_searching", {
            message: getTranslatorForUser(partnerId)("match.searching")
          });
        }
        await enqueueMatchmaking(redisClient, partnerId, queueKeyForMode(mode));
        await matchUsers(partnerId, mode);
      }
      addLog("info", "User disconnected", {
        userId: disconnectedId,
        requestId: requestIdValue
      });
    });
  } catch (err) {
    addLog("error", "Socket connection denied", { error: err.message, requestId: requestIdValue });
    const t = socket.data?.t || ((key) => key);
    const message =
      err.message === "token_revoked"
        ? t("errors.tokenRevoked")
        : err.message === "account_banned"
          ? t("errors.accountBanned")
          : t("errors.authError");
    socket.emit("banned", { message });
    socket.disconnect(true);
  }
});

app.get("/health", health);
app.get("/api/config", getConfig(redisClient));
app.get("/api/maintenance", getMaintenance(redisClient));
app.post("/api/auth/anonymous", registerAnonymous(pool, redisClient));
app.get("/api/profile", ensureAuth(redisClient), getProfile(pool));
app.post("/api/profile", ensureAuth(redisClient), upsertProfile(pool));
app.get("/api/friends", ensureAuth(redisClient), getFriends(pool));
app.get("/api/friends/:friendId/messages", ensureAuth(redisClient), getFriendMessages(pool));
app.post(
  "/api/friends/:friendId/messages",
  ensureAuth(redisClient),
  sendFriendMessage(pool, io, socketByUser)
);
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
  getStats(pool, redisClient, {
    getBackendInstanceCount: () => 1,
    getActiveConnections: () => socketByUser.size,
    getQueueLength: async () => {
      const [talk, meet] = await Promise.all([
        redisClient.zCard(QUEUE_KEY_TALK),
        redisClient.zCard(QUEUE_KEY_MEET)
      ]);
      return talk + meet;
    }
  })
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
  banUser(pool, redisClient, io, socketByUser)
);
app.post(
  "/api/admin/maintenance",
  ensureAuth(redisClient),
  ensureAdmin,
  updateMaintenance(redisClient, io)
);
app.get(
  "/api/admin/system-snapshot",
  ensureAuth(redisClient),
  ensureAdmin,
  getSystemSnapshot(redisClient, {
    getActiveMatches: async () => Math.floor(pairings.size / 2),
    getQueueLength: async () => {
      const [talk, meet] = await Promise.all([
        redisClient.zCard(QUEUE_KEY_TALK),
        redisClient.zCard(QUEUE_KEY_MEET)
      ]);
      return talk + meet;
    },
    getMediaCleanupStatus: async () => ({
      ...mediaCleanupStatus
    })
  })
);

const startServer = async () => {
  try {
    await initI18n();
    await connectRedis();
    await ensureMaintenanceDefaults(redisClient);
    await initDb();
    await cleanupOldMedia().catch((err) => {
      logger.warn({ err }, "Failed to run initial media cleanup");
    });

    const cleanupIntervalMs = Number(process.env.MEDIA_CLEANUP_INTERVAL_MS || 6 * 60 * 60 * 1000);
    setInterval(() => {
      cleanupOldMedia().catch((err) => {
        logger.warn({ err }, "Media cleanup failed");
      });
    }, cleanupIntervalMs);

    const port = Number(process.env.PORT || 3000);
    server.listen(port, () => {
      logger.info({ requestId: "startup", containerId, port }, "Backend listening");
    });
  } catch (err) {
    logger.error({ err }, "Failed to start server");
    process.exit(1);
  }
};

startServer();

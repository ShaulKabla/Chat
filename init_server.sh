#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "ERROR: $1" >&2
  exit 1
}

trap 'error "Command failed on line $LINENO. Please review the output above."' ERR

if [[ "${EUID}" -ne 0 ]]; then
  error "Please run this script as root using: sudo bash init_server.sh"
fi

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is not installed. Install Docker and Docker Compose before running this script."
fi

if ! docker compose version >/dev/null 2>&1; then
  error "Docker Compose plugin is not available. Install docker-compose-plugin before running this script."
fi

PROJECT_DIR="/opt/anon-chat-pro"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -hex 12 2>/dev/null || echo "ChangeMeNow!")"
JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || echo "change_this_super_secret")"
POSTGRES_USER="anonchat"
POSTGRES_PASSWORD="$(openssl rand -hex 12 2>/dev/null || echo "change_me")"
POSTGRES_DB="anonchat"
DOMAIN="chat.example.com"
BACKUP_SCHEDULE="0 3 * * *"

echo "==> Creating project structure at ${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}/backend" "${PROJECT_DIR}/admin-panel/src" "${PROJECT_DIR}/nginx/templates" "${PROJECT_DIR}/certbot/www" "${PROJECT_DIR}/certbot/conf" "${PROJECT_DIR}/backups" "${PROJECT_DIR}/scripts"

cat <<EOF > "${PROJECT_DIR}/.env"
DOMAIN=${DOMAIN}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
BACKUP_SCHEDULE=${BACKUP_SCHEDULE}
EOF

cat <<'EOF' > "${PROJECT_DIR}/docker-compose.yml"
services:
  postgres:
    image: postgres:16
    container_name: anonchat_postgres
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7
    container_name: anonchat_redis
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backend:
    build:
      context: ./backend
    container_name: anonchat_backend
    env_file:
      - ./backend/.env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  admin-panel:
    build:
      context: ./admin-panel
    container_name: anonchat_admin
    depends_on:
      backend:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  nginx:
    image: nginx:1.27-alpine
    container_name: anonchat_proxy
    depends_on:
      admin-panel:
        condition: service_healthy
      backend:
        condition: service_healthy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/templates:/etc/nginx/templates:ro
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    environment:
      DOMAIN: ${DOMAIN}
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  certbot:
    image: certbot/certbot
    container_name: anonchat_certbot
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    entrypoint: >
      /bin/sh -c "trap exit TERM; while :; do certbot renew --webroot -w /var/www/certbot; sleep 12h; done"
    restart: unless-stopped

  db-backup:
    image: prodrigestivill/postgres-backup-local:16
    container_name: anonchat_backup
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_EXTRA_OPTS: "-Z6 --schema=public --blobs"
      SCHEDULE: ${BACKUP_SCHEDULE}
      BACKUP_DIR: /backups
    volumes:
      - /opt/anon-chat-pro/backups:/backups
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

cat <<EOF > "${PROJECT_DIR}/backend/.env"
PORT=3000
APP_VERSION=2.0.0
ADMIN_USER=${ADMIN_USER}
ADMIN_PASS=${ADMIN_PASS}
JWT_SECRET=${JWT_SECRET}
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_URL=redis://redis:6379
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX=200
LOG_BUFFER_SIZE=200
EOF

cat <<'EOF' > "${PROJECT_DIR}/backend/package.json"
{
  "name": "anon-chat-backend",
  "version": "2.0.0",
  "description": "Anonymous chat backend with Socket.io",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "express-rate-limit": "^7.3.1",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.12.0",
    "redis": "^4.7.0",
    "socket.io": "^4.7.5",
    "uuid": "^9.0.1"
  }
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/backend/Dockerfile"
FROM node:20-alpine

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY server.js ./

USER app

EXPOSE 3000

CMD ["node", "server.js"]
EOF

cat <<'EOF' > "${PROJECT_DIR}/backend/server.js"
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
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/package.json"
{
  "name": "anon-chat-admin",
  "version": "2.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 5173",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 5173"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "socket.io-client": "^4.7.5"
  },
  "devDependencies": {
    "@tailwindcss/forms": "^0.5.9",
    "@vitejs/plugin-react": "^4.3.1",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.45",
    "tailwindcss": "^3.4.10",
    "vite": "^5.4.2"
  }
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/vite.config.js"
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist"
  }
});
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/tailwind.config.js"
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {}
  },
  plugins: [require("@tailwindcss/forms")]
};
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/postcss.config.js"
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {}
  }
};
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/index.html"
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Anon Chat Admin</title>
  </head>
  <body class="bg-slate-950 text-slate-100">
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/src/main.jsx"
import React from "react";
import ReactDOM from "react-dom/client";
import "./styles.css";
import App from "./App.jsx";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/src/styles.css"
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  font-family: "Inter", sans-serif;
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/src/App.jsx"
import { useEffect, useMemo, useRef, useState } from "react";
import { io } from "socket.io-client";

const API_BASE = import.meta.env.VITE_API_BASE_URL || window.location.origin;

const fetchJson = async (url, options = {}) => {
  const response = await fetch(url, options);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || "Request failed");
  }
  return data;
};

const formatLogMeta = (meta) => {
  if (!meta) return "";
  try {
    return JSON.stringify(meta);
  } catch {
    return String(meta);
  }
};

export default function App() {
  const [token, setToken] = useState("");
  const [credentials, setCredentials] = useState({ username: "", password: "" });
  const [stats, setStats] = useState({ connectedUsers: 0, waitingUsers: 0, reports: 0 });
  const [reports, setReports] = useState([]);
  const [logs, setLogs] = useState([]);
  const [error, setError] = useState("");
  const socketRef = useRef(null);

  const headers = useMemo(
    () => ({
      "Content-Type": "application/json",
      Authorization: token ? `Bearer ${token}` : ""
    }),
    [token]
  );

  const loadData = async () => {
    if (!token) return;
    const [statsRes, reportsRes] = await Promise.all([
      fetchJson(`${API_BASE}/api/admin/stats`, { headers }),
      fetchJson(`${API_BASE}/api/admin/reported`, { headers })
    ]);
    setStats(statsRes);
    setReports(reportsRes.reports || []);
  };

  useEffect(() => {
    if (!token) return;
    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, [token]);

  useEffect(() => {
    if (!token) return;
    const socket = io(`${API_BASE}/admin`, {
      auth: { token },
      transports: ["websocket", "polling"]
    });

    socket.on("connect_error", (err) => {
      setError(err.message || "Failed to connect to log stream");
    });

    socket.on("log:history", (entries) => {
      setLogs(entries || []);
    });

    socket.on("log:entry", (entry) => {
      setLogs((prev) => [...prev, entry].slice(-200));
    });

    socketRef.current = socket;
    return () => {
      socket.disconnect();
    };
  }, [token]);

  const handleLogin = async (event) => {
    event.preventDefault();
    setError("");
    try {
      const data = await fetchJson(`${API_BASE}/api/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(credentials)
      });
      setToken(data.token);
    } catch (err) {
      setError(err.message);
    }
  };

  const handleBan = async (userId) => {
    setError("");
    try {
      await fetchJson(`${API_BASE}/api/admin/ban`, {
        method: "POST",
        headers,
        body: JSON.stringify({ userId, reason: "Admin action" })
      });
      await loadData();
    } catch (err) {
      setError(err.message);
    }
  };

  const handleLogout = async () => {
    try {
      if (token) {
        await fetchJson(`${API_BASE}/api/admin/logout`, {
          method: "POST",
          headers
        });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      socketRef.current?.disconnect();
      setToken("");
    }
  };

  if (!token) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6">
        <form
          onSubmit={handleLogin}
          className="bg-slate-900 p-8 rounded-2xl shadow-xl w-full max-w-sm space-y-4"
        >
          <h1 className="text-xl font-semibold">Admin Login</h1>
          {error && <p className="text-red-400 text-sm">{error}</p>}
          <div>
            <label className="text-sm">Username</label>
            <input
              className="mt-1 w-full rounded-lg bg-slate-800 border-slate-700"
              value={credentials.username}
              onChange={(event) =>
                setCredentials((prev) => ({ ...prev, username: event.target.value }))
              }
            />
          </div>
          <div>
            <label className="text-sm">Password</label>
            <input
              type="password"
              className="mt-1 w-full rounded-lg bg-slate-800 border-slate-700"
              value={credentials.password}
              onChange={(event) =>
                setCredentials((prev) => ({ ...prev, password: event.target.value }))
              }
            />
          </div>
          <button
            type="submit"
            className="w-full bg-indigo-500 hover:bg-indigo-400 transition px-4 py-2 rounded-lg font-semibold"
          >
            Sign in
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Anon Chat Admin</h1>
          <p className="text-slate-400">Live monitoring and moderation.</p>
        </div>
        <button
          onClick={handleLogout}
          className="text-sm text-slate-300 hover:text-white"
        >
          Log out
        </button>
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      <div className="grid gap-4 md:grid-cols-3 mb-8">
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Connected Users</p>
          <p className="text-3xl font-semibold">{stats.connectedUsers}</p>
        </div>
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Waiting Users</p>
          <p className="text-3xl font-semibold">{stats.waitingUsers}</p>
        </div>
        <div className="bg-slate-900 rounded-2xl p-5">
          <p className="text-slate-400 text-sm">Reports</p>
          <p className="text-3xl font-semibold">{stats.reports}</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="bg-slate-900 rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">Reported Users</h2>
          <div className="space-y-3">
            {reports.length === 0 && (
              <p className="text-slate-400 text-sm">No reports yet.</p>
            )}
            {reports.map((report) => (
              <div
                key={report.id}
                className="flex flex-col md:flex-row md:items-center md:justify-between gap-3 bg-slate-800 rounded-xl p-4"
              >
                <div>
                  <p className="text-sm text-slate-300">
                    Reported ID: <span className="font-semibold">{report.reported_id}</span>
                  </p>
                  <p className="text-xs text-slate-400">Reason: {report.reason}</p>
                  <p className="text-xs text-slate-500">
                    Reporter: {report.reporter_id} • {new Date(report.created_at).toLocaleString()}
                  </p>
                </div>
                <button
                  onClick={() => handleBan(report.reported_id)}
                  className="bg-red-500 hover:bg-red-400 transition px-4 py-2 rounded-lg text-sm font-semibold"
                >
                  Ban
                </button>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-4">System Logs</h2>
          <div className="h-96 overflow-y-auto space-y-3 pr-2">
            {logs.length === 0 && (
              <p className="text-slate-400 text-sm">No logs yet.</p>
            )}
            {logs.map((entry) => (
              <div key={entry.id} className="bg-slate-800 rounded-xl p-4">
                <div className="flex items-center justify-between text-xs text-slate-400">
                  <span>{new Date(entry.timestamp).toLocaleString()}</span>
                  <span className="uppercase">{entry.level}</span>
                </div>
                <p className="text-sm text-slate-200 mt-2">{entry.message}</p>
                {entry.meta && (
                  <p className="text-xs text-slate-500 mt-2 break-words">
                    {formatLogMeta(entry.meta)}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/Dockerfile"
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
EOF

cat <<'EOF' > "${PROJECT_DIR}/admin-panel/nginx.conf"
server {
  listen 8080;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location /health {
    add_header Content-Type text/plain;
    return 200 "ok";
  }

  location / {
    try_files $uri /index.html;
  }
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/nginx/templates/app.conf.template"
upstream backend_upstream {
  server backend:3000;
}

upstream admin_upstream {
  server admin-panel:8080;
}

server {
  listen 80;
  server_name ${DOMAIN};

  location /.well-known/acme-challenge/ {
    root /var/www/certbot;
  }

  location /health {
    add_header Content-Type text/plain;
    return 200 "ok";
  }

  location / {
    return 301 https://$host$request_uri;
  }
}

server {
  listen 443 ssl;
  server_name ${DOMAIN};

  ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;

  location /api/ {
    proxy_pass http://backend_upstream/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }

  location /socket.io/ {
    proxy_pass http://backend_upstream/socket.io/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }

  location / {
    proxy_pass http://admin_upstream/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }
}
EOF

cat <<'EOF' > "${PROJECT_DIR}/scripts/migrate_to_docker.sh"
#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "ERROR: $1" >&2
  exit 1
}

trap 'error "Command failed on line $LINENO. Please review the output above."' ERR

PROJECT_DIR="/opt/anon-chat-pro"

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is not installed. Please install Docker before running this migration."
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "${PROJECT_DIR} does not exist. Run the init_server.sh script first."
fi

mkdir -p "${PROJECT_DIR}/backups"

echo "==> Stopping any existing Node or Vite processes"
pkill -f "node .*server.js" || true
pkill -f "vite" || true

if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
  echo "==> Stopping previous Docker Compose stack (volumes preserved)"
  docker compose -f "${PROJECT_DIR}/docker-compose.yml" down || true
fi

echo "==> Removing legacy Nginx site if present"
if command -v nginx >/dev/null 2>&1; then
  rm -f /etc/nginx/sites-enabled/anon-chat-pro || true
  rm -f /etc/nginx/sites-available/anon-chat-pro || true
  systemctl reload nginx || true
fi

echo "==> Pulling latest images and rebuilding containers"
cd "${PROJECT_DIR}"

docker compose pull

docker compose up -d --build

echo "==> Migration complete. Dockerized stack is running."
EOF

chmod +x "${PROJECT_DIR}/scripts/migrate_to_docker.sh"

cd "${PROJECT_DIR}"

docker compose up -d --build

echo "==> Setup complete!"
echo "Admin user: ${ADMIN_USER}"
echo "Admin password: ${ADMIN_PASS}"
echo "JWT secret: ${JWT_SECRET}"
echo "Domain: ${DOMAIN}"
echo "To request SSL certificates (first time):"
echo "  docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN}"

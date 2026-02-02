const { v4: uuidv4 } = require("uuid");
const { logger, containerId } = require("./logger");

const logBuffer = [];
const logBufferSize = Number(process.env.LOG_BUFFER_SIZE || 200);
let adminNamespace = null;

const setAdminNamespace = (namespace) => {
  adminNamespace = namespace;
};

const addLog = (level, message, meta = {}) => {
  const entry = {
    id: uuidv4(),
    timestamp: new Date().toISOString(),
    level,
    message,
    meta: { ...meta, containerId }
  };
  logBuffer.push(entry);
  if (logBuffer.length > logBufferSize) {
    logBuffer.shift();
  }
  if (adminNamespace) {
    adminNamespace.emit("log:entry", entry);
  }
  logger[level]({ requestId: meta.requestId, ...meta }, message);
};

module.exports = {
  addLog,
  logBuffer,
  setAdminNamespace
};

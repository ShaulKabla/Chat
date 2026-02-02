const os = require("os");
const pino = require("pino");

const containerId = process.env.CONTAINER_ID || os.hostname();

const logger = pino({
  base: { containerId },
  timestamp: pino.stdTimeFunctions.isoTime
});

module.exports = { logger, containerId };

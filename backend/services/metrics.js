const client = require("prom-client");

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const activeConnections = new client.Gauge({
  name: "active_websocket_connections",
  help: "Active websocket connections",
  registers: [register]
});

const messagesTotal = new client.Counter({
  name: "chat_messages_total",
  help: "Total chat messages",
  registers: [register]
});

const redisLatency = new client.Histogram({
  name: "redis_latency_seconds",
  help: "Redis latency in seconds",
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.25, 0.5, 1],
  registers: [register]
});

const observeRedisLatency = async (redisClient) => {
  const start = process.hrtime.bigint();
  await redisClient.ping();
  const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
  redisLatency.observe(durationSeconds);
};

module.exports = {
  register,
  activeConnections,
  messagesTotal,
  redisLatency,
  observeRedisLatency
};

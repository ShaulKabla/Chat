const { createClient } = require("redis");
const { logger } = require("./logger");

const redisUrl = process.env.REDIS_URL;

const redisClient = createClient({ url: redisUrl });
const pubClient = createClient({ url: redisUrl });
const subClient = pubClient.duplicate();

redisClient.on("error", (err) => logger.error({ err }, "Redis error"));

const connectRedis = async () => {
  await redisClient.connect();
  await pubClient.connect();
  await subClient.connect();
};

module.exports = {
  redisClient,
  pubClient,
  subClient,
  connectRedis
};

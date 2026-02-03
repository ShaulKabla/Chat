const { createClient } = require("redis");
const { logger } = require("./logger");

const redisUrl = process.env.REDIS_URL;

const redisClient = createClient({ url: redisUrl });

redisClient.on("error", (err) => logger.error({ err }, "Redis error"));

const connectRedis = async () => {
  await redisClient.connect();
};

module.exports = {
  redisClient,
  connectRedis
};

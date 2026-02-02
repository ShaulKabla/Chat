const rateLimitKey = async (redisClient, key, windowSeconds, max) => {
  const multi = redisClient.multi();
  multi.incr(key);
  multi.expire(key, windowSeconds, "NX");
  const [count] = await multi.exec();
  return Number(count);
};

const createLimiter = ({ redisClient, windowSeconds, max, prefix }) => {
  return async (req, res, next) => {
    try {
      const key = `${prefix}:${req.ip}`;
      const count = await rateLimitKey(redisClient, key, windowSeconds, max);
      if (count > max) {
        return res.status(429).json({ error: "rate_limited" });
      }
      return next();
    } catch (err) {
      return next();
    }
  };
};

const socketLimiter = async (redisClient, key, windowSeconds, max) => {
  const count = await rateLimitKey(redisClient, key, windowSeconds, max);
  return count <= max;
};

module.exports = {
  createLimiter,
  socketLimiter
};

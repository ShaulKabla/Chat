const QUEUE_KEY_TALK = "matchmaking_queue:talk";
const QUEUE_KEY_MEET = "matchmaking_queue:meet";

const enqueueMatchmaking = async (redisClient, userId, queueKey = QUEUE_KEY_TALK) => {
  await redisClient.zAdd(queueKey, { score: Date.now(), value: userId });
};

const removeFromQueue = async (redisClient, userId, queueKey = QUEUE_KEY_TALK) => {
  await redisClient.zRem(queueKey, userId);
};

const getQueueCandidates = async (redisClient, limit = 50, queueKey = QUEUE_KEY_TALK) => {
  return redisClient.zRange(queueKey, 0, limit - 1);
};

module.exports = {
  enqueueMatchmaking,
  removeFromQueue,
  getQueueCandidates,
  QUEUE_KEY_TALK,
  QUEUE_KEY_MEET
};

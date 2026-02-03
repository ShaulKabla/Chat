const QUEUE_KEY_TALK = "matchmaking_queue:talk";
const QUEUE_KEY_MEET = "matchmaking_queue:meet";

const enqueueMatchmaking = async (redisClient, userId, queueKey = QUEUE_KEY_TALK) => {
  await redisClient.zAdd(queueKey, { score: Date.now(), value: userId });
};

const removeFromQueue = async (redisClient, userId, queueKey = QUEUE_KEY_TALK) => {
  await redisClient.zRem(queueKey, userId);
};

const getQueueCandidates = async (redisClient, limit = 50, queueKey = QUEUE_KEY_TALK) => {
  return redisClient.zRangeWithScores(queueKey, 0, limit - 1);
};

const getQueueScore = async (redisClient, userId, queueKey = QUEUE_KEY_TALK) => {
  const score = await redisClient.zScore(queueKey, userId);
  return score ? Number(score) : null;
};

module.exports = {
  enqueueMatchmaking,
  removeFromQueue,
  getQueueCandidates,
  getQueueScore,
  QUEUE_KEY_TALK,
  QUEUE_KEY_MEET
};

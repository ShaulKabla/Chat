const { addLog } = require("./logStream");

const STREAM_KEY = "matchmaking_stream";
const GROUP = "matchmakers";
const WAITING_SET = "matchmaking_waiting";

const matchScript = `
local waiting = KEYS[1]
local pairings = KEYS[2]
local userId = ARGV[1]
local score = ARGV[2]

local existing = redis.call('HGET', pairings, userId)
if existing then
  return { 'paired', existing }
end

local candidate = redis.call('ZRANGE', waiting, 0, 0)[1]
if not candidate then
  redis.call('ZADD', waiting, score, userId)
  return { 'queued' }
end

if candidate == userId then
  return { 'queued' }
end

redis.call('ZREM', waiting, candidate)
redis.call('HSET', pairings, userId, candidate, candidate, userId)
return { 'paired', candidate }
`;

const createGroup = async (redisClient) => {
  try {
    await redisClient.xGroupCreate(STREAM_KEY, GROUP, "0", { MKSTREAM: true });
  } catch (err) {
    if (!String(err?.message || "").includes("BUSYGROUP")) {
      throw err;
    }
  }
};

const enqueueMatchmaking = async (redisClient, userId) => {
  await redisClient.xAdd(STREAM_KEY, "*", {
    userId,
    timestamp: Date.now().toString()
  });
};

const removeFromWaiting = async (redisClient, userId) => {
  await redisClient.zRem(WAITING_SET, userId);
};

const clearPairing = async (redisClient, userId) => {
  const partnerId = await redisClient.hGet("pairings", userId);
  if (partnerId) {
    await redisClient.hDel("pairings", partnerId);
  }
  await redisClient.hDel("pairings", userId);
  return partnerId;
};

const isBlockedPair = async (redisClient, userA, userB) => {
  const [blockedA, blockedB] = await Promise.all([
    redisClient.sIsMember(`blocked:${userA}`, userB),
    redisClient.sIsMember(`blocked:${userB}`, userA)
  ]);
  return blockedA === 1 || blockedB === 1;
};

const attemptMatch = async (redisClient, userId) => {
  const result = await redisClient.eval(matchScript, {
    keys: [WAITING_SET, "pairings"],
    arguments: [userId, Date.now().toString()]
  });
  return Array.isArray(result) ? result : ["queued"];
};

const requeueUsers = async (redisClient, ...userIds) => {
  const now = Date.now();
  const entries = userIds.filter(Boolean).map((id, index) => [now + index, id]);
  if (entries.length) {
    await redisClient.zAdd(WAITING_SET, entries);
  }
};

const startMatchmakingWorker = ({ redisClient, io, drainState, containerId }) => {
  let running = true;
  const consumer = `${containerId}-${process.pid}`;

  const loop = async () => {
    while (running) {
      try {
        const response = await redisClient.xReadGroup(
          GROUP,
          consumer,
          [{ key: STREAM_KEY, id: ">" }],
          { COUNT: 10, BLOCK: 5000 }
        );

        if (!response) {
          continue;
        }

        for (const stream of response) {
          for (const message of stream.messages) {
            const userId = message.message.userId;
            if (!userId) {
              await redisClient.xAck(STREAM_KEY, GROUP, message.id);
              continue;
            }

            if (drainState.enabled) {
              await redisClient.xAck(STREAM_KEY, GROUP, message.id);
              continue;
            }

            const [status, partnerId] = await attemptMatch(redisClient, userId);
            if (status === "paired" && partnerId) {
              const blocked = await isBlockedPair(redisClient, userId, partnerId);
              if (blocked) {
                await clearPairing(redisClient, userId);
                await requeueUsers(redisClient, userId, partnerId);
                await redisClient.xAck(STREAM_KEY, GROUP, message.id);
                continue;
              }

              const [socketA, socketB] = await Promise.all([
                redisClient.hGet("user_sockets", userId),
                redisClient.hGet("user_sockets", partnerId)
              ]);
              if (socketA) {
                io.to(socketA).emit("paired", { partnerId });
              }
              if (socketB) {
                io.to(socketB).emit("paired", { partnerId: userId });
              }
              addLog("info", "Users paired", { userId, partnerId });
            }

            await redisClient.xAck(STREAM_KEY, GROUP, message.id);
          }
        }
      } catch (err) {
        addLog("error", "Matchmaking worker error", { error: err.message });
      }
    }
  };

  loop();

  return () => {
    running = false;
  };
};

module.exports = {
  createGroup,
  enqueueMatchmaking,
  removeFromWaiting,
  clearPairing,
  isBlockedPair,
  startMatchmakingWorker
};

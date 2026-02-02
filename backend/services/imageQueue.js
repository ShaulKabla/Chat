const fs = require("fs/promises");
const path = require("path");
const { Queue, Worker, QueueEvents } = require("bullmq");
const IORedis = require("ioredis");
const sharp = require("sharp");
const { getStorageProvider } = require("./storage");
const { addLog } = require("./logStream");

const connection = new IORedis(process.env.REDIS_URL);

const queue = new Queue("image-processing", { connection });
const queueEvents = new QueueEvents("image-processing", { connection });

const storageProvider = getStorageProvider();

const worker = new Worker(
  "image-processing",
  async (job) => {
    const { tempPath, key, contentType } = job.data;
    const buffer = await sharp(tempPath)
      .rotate()
      .resize({ width: 1024, height: 1024, fit: "inside" })
      .toBuffer();

    const result = await storageProvider.save(buffer, key, contentType);
    await fs.unlink(tempPath).catch(() => {});
    return result;
  },
  { connection }
);

worker.on("failed", (job, err) => {
  addLog("error", "Image processing failed", { error: err.message, jobId: job?.id });
});

const enqueueImageProcessing = async ({ tempPath, filename, contentType }) => {
  const ext = path.extname(filename || "").replace(".", "") || "jpg";
  const key = `reports/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
  const job = await queue.add("process", { tempPath, key, contentType });
  const result = await job.waitUntilFinished(queueEvents);
  return result;
};

module.exports = { enqueueImageProcessing, queue, queueEvents };

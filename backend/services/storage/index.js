const path = require("path");
const LocalStorageProvider = require("./localProvider");
const S3StorageProvider = require("./s3Provider");

const getStorageProvider = () => {
  const mode = (process.env.STORAGE_MODE || "LOCAL").toUpperCase();
  if (mode === "S3") {
    return new S3StorageProvider({
      bucket: process.env.S3_BUCKET,
      region: process.env.S3_REGION,
      endpoint: process.env.S3_ENDPOINT,
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
      publicUrl: process.env.S3_PUBLIC_URL
    });
  }

  const uploadsDir = process.env.UPLOADS_DIR || path.resolve(__dirname, "../../../uploads");
  const publicUrl = (process.env.UPLOADS_PUBLIC_URL || "/uploads").replace(/\/$/, "");
  return new LocalStorageProvider({ uploadsDir, publicUrl });
};

module.exports = { getStorageProvider };

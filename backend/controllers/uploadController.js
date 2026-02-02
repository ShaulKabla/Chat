const fs = require("fs/promises");
const path = require("path");
const multer = require("multer");
const { enqueueImageProcessing } = require("../services/imageQueue");
const { addLog } = require("../services/logStream");

const tempDir = process.env.UPLOADS_TMP_DIR || "/tmp/uploads";

const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    try {
      await fs.mkdir(tempDir, { recursive: true });
      cb(null, tempDir);
    } catch (err) {
      cb(err, tempDir);
    }
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || "");
    const name = `${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`;
    cb(null, name);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith("image/")) {
      return cb(new Error("Invalid file type"));
    }
    return cb(null, true);
  }
});

const handleUpload = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "Missing file" });
  }
  try {
    const result = await enqueueImageProcessing({
      tempPath: req.file.path,
      filename: req.file.originalname,
      contentType: req.file.mimetype
    });
    addLog("info", "Image uploaded", { url: result.url, requestId: req.requestId });
    return res.json({ imageUrl: result.url, key: result.key });
  } catch (err) {
    addLog("error", "Image upload failed", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Upload failed" });
  }
};

module.exports = { upload, handleUpload };

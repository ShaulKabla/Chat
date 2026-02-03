const fs = require("fs/promises");
const path = require("path");
const { randomUUID } = require("crypto");
const multer = require("multer");
const sharp = require("sharp");
const { addLog } = require("../services/logStream");

const tempDir = process.env.UPLOADS_TMP_DIR || "/tmp/uploads";
const uploadsDir = process.env.UPLOADS_DIR || path.resolve(__dirname, "../../../uploads");
const publicUrl = (process.env.UPLOADS_PUBLIC_URL || "/uploads").replace(/\/$/, "");

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
    const reportsDir = path.join(uploadsDir, "reports");
    await fs.mkdir(reportsDir, { recursive: true });
    const filename = `${Date.now()}-${randomUUID()}.webp`;
    const targetPath = path.join(reportsDir, filename);

    await sharp(req.file.path)
      .rotate()
      .resize({ width: 1024, height: 1024, fit: "inside" })
      .webp({ quality: 80 })
      // Default sharp output strips metadata to remove EXIF data.
      .toFile(targetPath);
    await fs.unlink(req.file.path).catch(() => {});

    const imageUrl = `${publicUrl}/reports/${filename}`;
    addLog("info", "Image uploaded", { url: imageUrl, requestId: req.requestId });
    return res.json({ imageUrl });
  } catch (err) {
    addLog("error", "Image upload failed", { error: err.message, requestId: req.requestId });
    return res.status(500).json({ error: "Upload failed" });
  }
};

module.exports = { upload, handleUpload };

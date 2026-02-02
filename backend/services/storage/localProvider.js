const fs = require("fs/promises");
const path = require("path");

class LocalStorageProvider {
  constructor({ uploadsDir, publicUrl }) {
    this.uploadsDir = uploadsDir;
    this.publicUrl = publicUrl;
  }

  async save(buffer, key, contentType) {
    const targetPath = path.join(this.uploadsDir, key);
    await fs.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.writeFile(targetPath, buffer);
    return {
      key,
      url: `${this.publicUrl}/${key}`,
      contentType
    };
  }
}

module.exports = LocalStorageProvider;

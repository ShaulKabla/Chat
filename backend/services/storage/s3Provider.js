const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");

class S3StorageProvider {
  constructor({
    bucket,
    region,
    endpoint,
    accessKeyId,
    secretAccessKey,
    publicUrl
  }) {
    this.bucket = bucket;
    this.publicUrl = publicUrl;
    this.client = new S3Client({
      region,
      endpoint: endpoint || undefined,
      forcePathStyle: Boolean(endpoint),
      credentials: accessKeyId
        ? {
            accessKeyId,
            secretAccessKey
          }
        : undefined
    });
  }

  async save(buffer, key, contentType) {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
        ACL: "public-read"
      })
    );

    return {
      key,
      url: `${this.publicUrl}/${key}`,
      contentType
    };
  }
}

module.exports = S3StorageProvider;

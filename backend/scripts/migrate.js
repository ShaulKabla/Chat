const { pool } = require("../services/postgres");
const { logger } = require("../services/logger");

const runMigrations = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS reports (
      id SERIAL PRIMARY KEY,
      reporter_id TEXT NOT NULL,
      reported_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      image_url TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS reports_created_at_idx ON reports (created_at);`);
  await pool.query(`ALTER TABLE reports ADD COLUMN IF NOT EXISTS image_url TEXT;`);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bans (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS anonymous_users (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      fcm_token TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS profiles (
      user_id TEXT PRIMARY KEY,
      gender TEXT NOT NULL,
      age_group TEXT NOT NULL,
      interests TEXT[] NOT NULL,
      gender_preference TEXT NOT NULL DEFAULT 'any',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS blocks (
      blocker_id TEXT NOT NULL,
      blocked_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (blocker_id, blocked_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friends (
      user_id TEXT NOT NULL,
      friend_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (user_id, friend_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friend_requests (
      requester_id TEXT NOT NULL,
      addressee_id TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      PRIMARY KEY (requester_id, addressee_id)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS friend_messages (
      id SERIAL PRIMARY KEY,
      sender_id TEXT NOT NULL,
      recipient_id TEXT NOT NULL,
      body TEXT,
      image_url TEXT,
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  await pool.query(`CREATE INDEX IF NOT EXISTS friend_messages_created_at_idx ON friend_messages (created_at);`);
};

runMigrations()
  .then(async () => {
    await pool.end();
    logger.info({ requestId: "migration" }, "Database migrations complete");
    process.exit(0);
  })
  .catch(async (err) => {
    await pool.end().catch(() => {});
    logger.error({ err, requestId: "migration" }, "Database migrations failed");
    process.exit(1);
  });

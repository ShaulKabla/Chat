#!/usr/bin/env bash
set -euo pipefail

node <<'NODE'
const http = require('http');
const { createClient } = require('redis');
const { Pool } = require('pg');

const port = Number(process.env.PORT || 3000);

const checkHttp = () => new Promise((resolve, reject) => {
  const req = http.get({ hostname: '127.0.0.1', port, path: '/health', timeout: 2000 }, (res) => {
    if (res.statusCode === 200) {
      resolve();
    } else {
      reject(new Error(`health status ${res.statusCode}`));
    }
  });
  req.on('error', reject);
  req.on('timeout', () => {
    req.destroy();
    reject(new Error('health timeout'));
  });
});

const checkRedis = async () => {
  const client = createClient({ url: process.env.REDIS_URL });
  await client.connect();
  await client.ping();
  await client.disconnect();
};

const checkPostgres = async () => {
  const pool = new Pool({
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD
  });
  await pool.query('SELECT 1');
  await pool.end();
};

(async () => {
  try {
    await Promise.all([checkHttp(), checkRedis(), checkPostgres()]);
    process.exit(0);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
})();
NODE

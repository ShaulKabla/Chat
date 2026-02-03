#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=${1:-".env"}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

required_vars=(
  DOMAIN
  PORT
  APP_VERSION
  TRUST_PROXY
  JWT_SECRET
  ADMIN_USER
  ADMIN_PASS
  POSTGRES_HOST
  POSTGRES_PORT
  POSTGRES_DB
  POSTGRES_USER
  POSTGRES_PASSWORD
  REDIS_URL
  REDIS_STREAM_KEY
  ADMIN_LOGIN_WINDOW_SEC
  ADMIN_LOGIN_MAX
  UPLOAD_WINDOW_SEC
  UPLOAD_MAX
  CHAT_WINDOW_SEC
  CHAT_MAX
  UPLOADS_DIR
  UPLOADS_PUBLIC_URL
  UPLOADS_TMP_DIR
  STORAGE_MODE
  LOG_BUFFER_SIZE
  MAINTENANCE_MESSAGE
  CLIENT_MAX_BODY_SIZE
  REAL_IP_FROM
  CSP_POLICY
)

missing=()

for var in "${required_vars[@]}"; do
  value=$(grep -E "^${var}=" "$ENV_FILE" | tail -n1 | cut -d= -f2- || true)
  if [[ -z "$value" ]]; then
    missing+=("$var")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing required env vars in $ENV_FILE:" >&2
  printf ' - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "Environment validation passed for $ENV_FILE"

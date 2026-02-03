#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "ERROR: $1" >&2
  exit 1
}

trap 'error "Command failed on line $LINENO. Please review the output above."' ERR

if [[ "${EUID}" -ne 0 ]]; then
  error "Please run this script as root using: sudo bash init_server.sh"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
COMPOSE_COMMAND=${COMPOSE_COMMAND:-"docker compose"}

install_docker_apt() {
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_yum() {
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    install_docker_apt
  elif command -v yum >/dev/null 2>&1; then
    install_docker_yum
  else
    error "Unsupported package manager. Install Docker manually and re-run this script."
  fi

  systemctl enable --now docker
}

ensure_compose() {
  if docker compose version >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y docker-compose-plugin
  elif command -v yum >/dev/null 2>&1; then
    yum install -y docker-compose-plugin
  else
    error "Unable to install docker compose plugin automatically."
  fi
}

echo "==> Ensuring Docker is installed"
ensure_docker
echo "==> Ensuring Docker Compose plugin is installed"
ensure_compose

mkdir -p \
  "${ROOT_DIR}/uploads/meet/previews" \
  "${ROOT_DIR}/uploads/meet/sources" \
  "${ROOT_DIR}/uploads/reports" \
  "${ROOT_DIR}/uploads/friends" \
  "${ROOT_DIR}/certbot/www" \
  "${ROOT_DIR}/certbot/conf"

JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || echo "change_this_super_secret")"
POSTGRES_PASSWORD="$(openssl rand -hex 12 2>/dev/null || echo "change_me")"

cat <<EOF_ENV > "$ENV_FILE"
# Core
DOMAIN=109.207.76.45
PORT=3000
APP_VERSION=2.1.0
TRUST_PROXY=loopback
CONTAINER_ID=

# Authentication
JWT_SECRET=${JWT_SECRET}
ADMIN_USER=admin
ADMIN_PASS=dkUsW3tghcyjwvjeJAD2

# Postgres
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=anonchat
POSTGRES_USER=anonchat
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Redis
REDIS_URL=redis://redis:6379
REDIS_STREAM_KEY=matchmaking:events

# Rate limits (seconds)
ADMIN_LOGIN_WINDOW_SEC=600
ADMIN_LOGIN_MAX=5
UPLOAD_WINDOW_SEC=600
UPLOAD_MAX=10
CHAT_WINDOW_SEC=5
CHAT_MAX=20
SKIP_WINDOW_SEC=30
SKIP_MAX=6
CONNECT_WINDOW_SEC=60
CONNECT_MAX=4

# Uploads & Storage
UPLOADS_DIR=/uploads
UPLOADS_PUBLIC_URL=http://109.207.76.45/uploads
UPLOADS_TMP_DIR=/tmp/uploads
MEDIA_RETENTION_DAYS=5
MEDIA_CLEANUP_INTERVAL_MS=21600000
REVEAL_DELAY_MS=420000
STORAGE_MODE=LOCAL

# Logging
LOG_BUFFER_SIZE=200

# Maintenance
MAINTENANCE_MESSAGE=We are performing scheduled maintenance. Please try again shortly.

# Nginx
CLIENT_MAX_BODY_SIZE=20m
REAL_IP_FROM=10.0.0.0/8
CSP_POLICY=default-src 'self'; connect-src 'self' wss:; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'

# Admin panel (build-time)
VITE_API_BASE_URL=http://109.207.76.45
EOF_ENV

echo "==> Validating environment"
"${ROOT_DIR}/scripts/validate_env.sh" "$ENV_FILE"

echo "==> Resetting existing containers"
$COMPOSE_COMMAND -f "${ROOT_DIR}/docker-compose.yml" down -v --remove-orphans

echo "==> Starting core services"
$COMPOSE_COMMAND -f "${ROOT_DIR}/docker-compose.yml" up -d --build postgres redis

echo "==> Running database migrations"
$COMPOSE_COMMAND -f "${ROOT_DIR}/docker-compose.yml" run --rm db-migrate

echo "==> Starting application services"
$COMPOSE_COMMAND -f "${ROOT_DIR}/docker-compose.yml" up -d --build backend admin-panel nginx certbot

echo "==> Initialization complete. Containers are starting in the background."

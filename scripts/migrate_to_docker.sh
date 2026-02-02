#!/usr/bin/env bash
set -euo pipefail

error() {
  echo "ERROR: $1" >&2
  exit 1
}

trap 'error "Command failed on line $LINENO. Please review the output above."' ERR

PROJECT_DIR="/opt/anon-chat-pro"

if ! command -v docker >/dev/null 2>&1; then
  error "Docker is not installed. Please install Docker before running this migration."
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  error "${PROJECT_DIR} does not exist. Run the init_server.sh script first."
fi

mkdir -p "${PROJECT_DIR}/backups"

echo "==> Stopping any existing Node or Vite processes"
pkill -f "node .*server.js" || true
pkill -f "vite" || true

if [[ -f "${PROJECT_DIR}/docker-compose.yml" ]]; then
  echo "==> Stopping previous Docker Compose stack (volumes preserved)"
  docker compose -f "${PROJECT_DIR}/docker-compose.yml" down || true
fi

echo "==> Removing legacy Nginx site if present"
if command -v nginx >/dev/null 2>&1; then
  rm -f /etc/nginx/sites-enabled/anon-chat-pro || true
  rm -f /etc/nginx/sites-available/anon-chat-pro || true
  systemctl reload nginx || true
fi

echo "==> Pulling latest images and rebuilding containers"
cd "${PROJECT_DIR}"

docker compose pull

docker compose up -d --build

echo "==> Migration complete. Dockerized stack is running."

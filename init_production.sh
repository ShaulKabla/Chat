#!/usr/bin/env bash
set -euo pipefail

COMPOSE_COMMAND=${COMPOSE_COMMAND:-"docker compose"}
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-180}
HEALTH_POLL_INTERVAL=${HEALTH_POLL_INTERVAL:-3}

CORE_SERVICES=(
  postgres
  redis
  backend
  admin-panel
)

EDGE_SERVICES=(
  nginx
  certbot
)

check_service() {
  local service=$1
  local container_id
  container_id=$($COMPOSE_COMMAND ps -q "$service")

  if [[ -z "$container_id" ]]; then
    echo "Service $service did not start." >&2
    return 1
  fi

  local deadline=$((SECONDS + HEALTH_TIMEOUT))
  while [[ $SECONDS -lt $deadline ]]; do
    local status health
    status=$(docker inspect -f '{{.State.Status}}' "$container_id")
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id")

    if [[ "$health" == "healthy" ]]; then
      echo "Service $service is healthy."
      return 0
    fi

    if [[ "$health" == "none" && "$status" == "running" ]]; then
      echo "Service $service is running (no healthcheck)."
      return 0
    fi

    if [[ "$status" == "exited" || "$health" == "unhealthy" ]]; then
      echo "Service $service failed with status $status (health: $health)." >&2
      docker logs --tail 50 "$container_id" || true
      return 1
    fi

    sleep "$HEALTH_POLL_INTERVAL"
  done

  echo "Timed out waiting for $service to become healthy." >&2
  docker logs --tail 50 "$container_id" || true
  return 1
}

echo "Validating configuration..."
./scripts/validate_env.sh

echo "Resetting existing containers and volumes..."
$COMPOSE_COMMAND down -v --remove-orphans

echo "Starting core dependencies..."
$COMPOSE_COMMAND up -d --build postgres redis

check_service postgres
check_service redis

echo "Running database migrations..."
$COMPOSE_COMMAND run --rm db-migrate

echo "Starting application services..."
$COMPOSE_COMMAND up -d --build backend admin-panel

for service in backend admin-panel; do
  check_service "$service"
done

echo "Starting edge services..."
$COMPOSE_COMMAND up -d --build "${EDGE_SERVICES[@]}"

for service in "${EDGE_SERVICES[@]}"; do
  check_service "$service"
done

echo "Production environment initialized successfully."

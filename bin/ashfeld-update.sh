#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-all}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_DIR"
git pull
chmod +x bin/ashfeld-*.sh 2>/dev/null || true

wait_healthy() {
  local TIMEOUT=120 ELAPSED=0
  until [ -z "$(docker ps --filter health=starting --filter health=unhealthy --format '{{.Names}}')" ]; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
      echo "Warning: timed out waiting for containers to become healthy."
      break
    fi
    sleep 15
    ELAPSED=$((ELAPSED + 15))
  done
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

case "$TARGET" in
  darkhorn)
    docker compose -f darkhorn/docker-compose.yml up --build -d 2>/dev/null
    ;;
  hollowcrown)
    docker compose -f hollowcrown/docker-compose.yml up --build -d 2>/dev/null
    ;;
  all)
    docker compose -f hollowcrown/docker-compose.yml up --build -d 2>/dev/null
    docker compose -f darkhorn/docker-compose.yml up --build -d 2>/dev/null
    ;;
  *)
    echo "Usage: ashfeld-update.sh [darkhorn|hollowcrown|all]"
    exit 1
    ;;
esac

wait_healthy

#!/usr/bin/env bash
set -euo pipefail

ASHFELD_DIR=~/ashfeld

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

if [ -d "$ASHFELD_DIR" ]; then
  echo "Error: $ASHFELD_DIR already exists. Run ashfeld-cleanup.sh first."
  exit 1
fi

git clone -q "https://github.com/reapicorn/ashfeld" "$ASHFELD_DIR"
bash "$ASHFELD_DIR/bin/ashfeld-setenv.sh"
docker compose -f "$ASHFELD_DIR/darkhorn/docker-compose.yml" up --build -d > /dev/null 2>&1
docker compose -f "$ASHFELD_DIR/hollowcrown/docker-compose.yml" up --build -d > /dev/null 2>&1

wait_healthy

#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/reapicorn/ashfeld"
INSTALL_DIR=~/ashfeld

if [ -d "$INSTALL_DIR" ]; then
  echo "Error: $INSTALL_DIR already exists. Run ashfeld-cleanup.sh first."
  exit 1
fi

git clone -q "$REPO" "$INSTALL_DIR"
bash "$INSTALL_DIR/bin/ashfeld-setenv.sh"
docker compose -f "$INSTALL_DIR/darkhorn/docker-compose.yml" up --build -d > /dev/null 2>&1
docker compose -f "$INSTALL_DIR/hollowcrown/docker-compose.yml" up --build -d > /dev/null 2>&1

TIMEOUT=120
ELAPSED=0
until [ -z "$(docker ps --filter health=starting --filter health=unhealthy --format '{{.Names}}')" ]; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "Warning: timed out waiting for containers to become healthy."
    break
  fi
  sleep 15
  ELAPSED=$((ELAPSED + 15))
done

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

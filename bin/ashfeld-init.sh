#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/reapicorn/ashfeld"
INSTALL_DIR=~/ashfeld

if [ -d "$INSTALL_DIR" ]; then
  echo "Error: $INSTALL_DIR already exists. Run ashfeld-cleanup.sh first."
  exit 1
fi

git clone -q "$REPO" "$INSTALL_DIR"
docker compose -f "$INSTALL_DIR/darkhorn/docker-compose.yml" up --build -d > /dev/null 2>&1
docker compose -f "$INSTALL_DIR/hollowcrown/docker-compose.yml" up --build -d > /dev/null 2>&1
sleep 60

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

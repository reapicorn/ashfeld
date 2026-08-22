#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/reapicorn/ashfeld"
INSTALL_DIR=~/ashfeld

if [ -d "$INSTALL_DIR" ]; then
  echo "Error: $INSTALL_DIR already exists. Run ashfeld-cleanup.sh first."
  exit 1
fi

echo "Cloning repo..."
git clone "$REPO" "$INSTALL_DIR"

echo "Starting darkhorn..."
docker compose -f "$INSTALL_DIR/darkhorn/docker-compose.yml" up --build -d > /dev/null 2>&1

echo "Starting hollowcrown..."
docker compose -f "$INSTALL_DIR/hollowcrown/docker-compose.yml" up --build -d > /dev/null 2>&1

echo "Waiting for containers to settle..."
sleep 60

echo ""
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

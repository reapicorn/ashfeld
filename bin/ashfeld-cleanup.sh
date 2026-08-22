#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=~/ashfeld

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Nothing to clean up — $INSTALL_DIR does not exist."
  exit 0
fi

echo "Stopping and removing all containers..."
docker compose -f "$INSTALL_DIR/darkhorn/docker-compose.yml" down -v 2>/dev/null || true
docker compose -f "$INSTALL_DIR/hollowcrown/docker-compose.yml" down -v 2>/dev/null || true

echo "Removing leftover volumes..."
docker volume ls --filter name=darkhorn --quiet | xargs -r docker volume rm 2>/dev/null || true
docker volume ls --filter name=hollowcrown --quiet | xargs -r docker volume rm 2>/dev/null || true

echo "Removing built images..."
docker images --filter reference='darkhorn-*' --quiet | xargs -r docker rmi -f 2>/dev/null || true
docker images --filter reference='hollowcrown-*' --quiet | xargs -r docker rmi -f 2>/dev/null || true

echo "Removing repo..."
rm -rf "$INSTALL_DIR"
cd ~

echo "Done."

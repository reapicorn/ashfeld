#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=~/ashfeld

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Nothing to clean up."
  exit 0
fi

docker compose -f "$INSTALL_DIR/darkhorn/docker-compose.yml" down -v > /dev/null 2>&1 || true
docker compose -f "$INSTALL_DIR/hollowcrown/docker-compose.yml" down -v > /dev/null 2>&1 || true
docker volume ls --filter name=darkhorn --quiet | xargs -r docker volume rm > /dev/null 2>&1 || true
docker volume ls --filter name=hollowcrown --quiet | xargs -r docker volume rm > /dev/null 2>&1 || true
docker images --filter reference='darkhorn-*' --quiet | xargs -r docker rmi -f > /dev/null 2>&1 || true
docker images --filter reference='hollowcrown-*' --quiet | xargs -r docker rmi -f > /dev/null 2>&1 || true
rm -rf "$INSTALL_DIR"

echo "Done."

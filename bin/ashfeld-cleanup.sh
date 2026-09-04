#!/usr/bin/env bash
set -euo pipefail

ASHFELD_DIR=~/ashfeld

if [ ! -d "$ASHFELD_DIR" ]; then
  echo "Nothing to clean up."
  exit 0
fi

docker compose -f "$ASHFELD_DIR/darkhorn/docker-compose.yml" down -v 2>/dev/null || true
docker volume ls --filter name=darkhorn --quiet | xargs -r docker volume rm 2>/dev/null || true
docker images --filter reference='darkhorn-*' --quiet | xargs -r docker rmi -f 2>/dev/null || true
rm -rf "$ASHFELD_DIR"

echo "Done."

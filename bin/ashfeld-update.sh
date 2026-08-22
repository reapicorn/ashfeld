#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-all}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_DIR"
git pull
chmod +x bin/ashfeld-*.sh

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

echo "Done."

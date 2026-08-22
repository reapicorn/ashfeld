#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_DIR"
git pull
chmod +x bin/ashfeld-*.sh

docker compose -f hollowcrown/docker-compose.yml up --build -d > /dev/null 2>&1

echo "Done."

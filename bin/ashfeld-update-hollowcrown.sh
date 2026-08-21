#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

echo "==> Pulling latest changes..."
git pull

echo "==> Rebuilding hollowcrown..."
cd hollowcrown
docker compose up --build -d

echo "==> Done."

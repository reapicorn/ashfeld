#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$REPO_DIR/bin"

cd "$REPO_DIR"

echo "==> Pulling latest changes..."
git checkout -- .
git pull
chmod +x "$BIN_DIR"/ashfeld-*.sh

echo "==> Rebuilding hollowcrown..."
cd hollowcrown
docker compose up --build -d
cd ..

echo "==> Rebuilding darkhorn..."
cd darkhorn
docker compose up --build -d
cd ..

echo "==> Done."

#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../darkhorn"
docker compose up --build -d
echo "==> darkhorn rebuilt."

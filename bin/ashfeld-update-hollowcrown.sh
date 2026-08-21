#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../hollowcrown"
docker compose up --build -d
echo "==> hollowcrown rebuilt."

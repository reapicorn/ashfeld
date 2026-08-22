#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"

chmod +x "$BIN_DIR"/ashfeld-*.sh

EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\""

if ! grep -qF "$EXPORT_LINE" ~/.bashrc 2>/dev/null; then
  echo "$EXPORT_LINE" >> ~/.bashrc
fi

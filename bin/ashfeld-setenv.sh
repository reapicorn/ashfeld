#!/usr/bin/env bash
set -euo pipefail

ASHFELD_DIR=~/ashfeld
BIN_DIR="$ASHFELD_DIR/bin"

chmod +x "$BIN_DIR"/ashfeld-*.sh

EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\""

if ! grep -qF "$EXPORT_LINE" ~/.bashrc 2>/dev/null; then
  echo "$EXPORT_LINE" >> ~/.bashrc
fi

echo "Run 'source ~/.bashrc' to apply."

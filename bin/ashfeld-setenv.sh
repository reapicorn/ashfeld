#!/usr/bin/env bash
set -e

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"

chmod +x "$BIN_DIR"/ashfeld-*.sh

EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\""

if grep -qF "$EXPORT_LINE" ~/.bashrc 2>/dev/null; then
  echo "PATH already configured in ~/.bashrc."
else
  echo "$EXPORT_LINE" >> ~/.bashrc
  echo "Added $BIN_DIR to PATH in ~/.bashrc."
fi

echo "Run 'source ~/.bashrc' or open a new shell to apply."

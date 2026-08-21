#!/usr/bin/env bash
set -e

ASHFELD_DIR="$(cd "$(dirname "$0")" && pwd)"

chmod +x \
  "$ASHFELD_DIR/ashfeld-update.sh" \
  "$ASHFELD_DIR/ashfeld-update-hollowcrown.sh" \
  "$ASHFELD_DIR/ashfeld-update-darkhorn.sh"

EXPORT_LINE="export PATH=\"$ASHFELD_DIR:\$PATH\""

if grep -qF "$EXPORT_LINE" ~/.bashrc 2>/dev/null; then
  echo "==> PATH already configured in ~/.bashrc, skipping."
else
  echo "$EXPORT_LINE" >> ~/.bashrc
  echo "==> Added $ASHFELD_DIR to PATH in ~/.bashrc."
fi

echo "==> Run 'source ~/.bashrc' or open a new shell to apply."

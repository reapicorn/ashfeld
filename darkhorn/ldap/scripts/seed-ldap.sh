#!/bin/bash
# ldap/scripts/seed-ldap.sh
# Runs the LDIF generator then imports into the running OpenLDAP container.
# Usage: ./scripts/seed-ldap.sh [container-name]
#   container-name defaults to darkhorn-ldap

set -e

CONTAINER=${1:-darkhorn-ldap}
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOTSTRAP_DIR="$SCRIPTS_DIR/../bootstrap"

echo "[ldap-seed] Generating LDIF files..."
python3 "$SCRIPTS_DIR/generate-seed-ldif.py"

echo "[ldap-seed] Importing users..."
docker exec -i "$CONTAINER" ldapadd -x \
  -D "cn=admin,dc=darkhorn,dc=local" \
  -w 'Bl4ckTr33Admin!' \
  < "$BOOTSTRAP_DIR/02-users.ldif" \
  || echo "[ldap-seed] Users import error (may already exist)"

echo "[ldap-seed] Importing groups..."
docker exec -i "$CONTAINER" ldapadd -x \
  -D "cn=admin,dc=darkhorn,dc=local" \
  -w 'Bl4ckTr33Admin!' \
  < "$BOOTSTRAP_DIR/03-groups.ldif" \
  || echo "[ldap-seed] Groups import error (may already exist)"

echo "[ldap-seed] Done."

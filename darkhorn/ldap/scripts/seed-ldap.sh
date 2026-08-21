#!/bin/bash
# ldap/scripts/seed-ldap.sh
# Runs the LDIF generator then imports into the running OpenLDAP container.
# Usage: ./scripts/seed-ldap.sh [container-name]
#   container-name defaults to darkhorn-ldap

set -e

CONTAINER=${1:-darkhorn-ldap}
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "[ldap-seed] Generating LDIF files..."
python3 "$SCRIPTS_DIR/generate-seed-ldif.py" --out "$TMP_DIR"

echo "[ldap-seed] Waiting for $CONTAINER to be ready..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" ldapsearch -x \
      -H ldap://localhost \
      -D "cn=admin,dc=darkhorn,dc=local" \
      -w 'Bl4ckTr33Admin!' \
      -b "dc=darkhorn,dc=local" \
      "(objectClass=*)" dn > /dev/null 2>&1; then
    echo "[ldap-seed] Container is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "[ldap-seed] Timed out waiting for $CONTAINER." >&2
    exit 1
  fi
  sleep 2
done

echo "[ldap-seed] Importing users..."
docker exec -i "$CONTAINER" ldapadd -x \
  -D "cn=admin,dc=darkhorn,dc=local" \
  -w 'Bl4ckTr33Admin!' \
  < "$TMP_DIR/02-users.ldif" \
  || echo "[ldap-seed] Users import error (may already exist)"

echo "[ldap-seed] Importing groups..."
docker exec -i "$CONTAINER" ldapadd -x \
  -D "cn=admin,dc=darkhorn,dc=local" \
  -w 'Bl4ckTr33Admin!' \
  < "$TMP_DIR/03-groups.ldif" \
  || echo "[ldap-seed] Groups import error (may already exist)"

echo "[ldap-seed] Done."

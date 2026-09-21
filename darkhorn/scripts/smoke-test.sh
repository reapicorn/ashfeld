#!/bin/bash
# darkhorn/scripts/smoke-test.sh
# Smoke-tests all six darkhorn backends.
#
# Run from the host (Linux/macOS with curl installed):
#   bash darkhorn/scripts/smoke-test.sh
#
# JDBC and LDAP checks require psql and ldap-utils. If not installed locally,
# run via a container that has them:
#   docker compose exec darkhorn-rest bash /scripts/smoke-test.sh
#
# HOST can be overridden for remote targets:
#   HOST=10.10.10.20 bash darkhorn/scripts/smoke-test.sh

set -euo pipefail

IP="${HOST:-localhost}"
PASS=0
FAIL=0

ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1" | head -c 200; echo; FAIL=$((FAIL+1)); }

# Wait for a service to respond (max 60s)
wait_for() {
  local url=$1 retries=12
  while [ $retries -gt 0 ]; do
    curl -sf "$url" -o /dev/null 2>/dev/null && return 0
    retries=$((retries-1))
    sleep 5
  done
  return 1
}

# -- REST --------------------------------------------------------------------------
echo ""
echo "REST  http://$IP:3000"

wait_for "http://$IP:3000/api/health" || { fail "REST not reachable after 60s"; }

out=$(curl -sf "http://$IP:3000/api/health" 2>&1) || true
if echo "$out" | grep -q '"status".*"ok"'; then ok "GET /api/health -> ok"
else fail "GET /api/health: $out"; fi

out=$(curl -sf -X POST "http://$IP:3000/oauth/token" \
  -d 'grant_type=client_credentials&client_id=voidhorn&client_secret=v01dh0rn$3cr3t!' 2>&1) || true
if echo "$out" | grep -q "access_token"; then ok "POST /oauth/token -> token obtained"
else fail "POST /oauth/token: $out"; fi

out=$(curl -sf "http://$IP:3000/api/users" -u 'grimreaper:Wh1sp3r0fD4rk!' 2>&1) || true
count=$(echo "$out" | grep -o '"totalResults":[0-9]*' | grep -o '[0-9]*')
if [ -n "$count" ]; then ok "GET /api/users -> $count users"
else fail "GET /api/users: $out"; fi

# -- JDBC --------------------------------------------------------------------------
echo ""
echo "JDBC  $IP:5432"

if command -v psql &>/dev/null; then
  out=$(PGPASSWORD='darkhorn' psql -h "$IP" -p 5432 -U darkhorn -d darkhorn_jdbc -tAc 'SELECT COUNT(*) FROM users;' 2>&1) || true
  count=$(echo "$out" | grep -E '^[0-9]+$' | head -1)
  if [ -n "$count" ]; then ok "SELECT COUNT(*) FROM users -> $count rows"
  else fail "psql: $out"; fi
else
  echo "  [SKIP] psql not found — skipping JDBC check"
fi

# -- LDAP --------------------------------------------------------------------------
echo ""
echo "LDAP  $IP:389"

if command -v ldapsearch &>/dev/null; then
  retries=12
  until ldapsearch -x -H "ldap://$IP:389" \
    -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
    -w 'Sp3ctr3Qu13t!' \
    -b 'ou=Users,dc=darkhorn,dc=local' \
    '(objectClass=inetOrgPerson)' dn 2>/dev/null | grep -q '^dn:'; do
    retries=$((retries-1))
    [ $retries -eq 0 ] && break
    sleep 5
  done

  count=$(ldapsearch -x -H "ldap://$IP:389" \
    -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
    -w 'Sp3ctr3Qu13t!' \
    -b 'ou=Users,dc=darkhorn,dc=local' \
    '(objectClass=inetOrgPerson)' dn 2>&1 | grep -c '^dn:') || true
  if [ "$count" -gt 0 ] 2>/dev/null; then ok "ldapsearch inetOrgPerson -> $count entries"
  else fail "ldapsearch returned $count entries"; fi
else
  echo "  [SKIP] ldapsearch not found — skipping LDAP check"
fi

# -- SFTP --------------------------------------------------------------------------
echo ""
echo "SFTP  $IP:2222"

if command -v sshpass &>/dev/null && command -v sftp &>/dev/null; then
  out=$(sshpass -p 'Sp3ctr4lF1l3!' sftp -o StrictHostKeyChecking=no -P 2222 \
    "spectral@$IP" <<< 'ls darkhorn' 2>&1) || true
  if echo "$out" | grep -q "users.csv"; then ok "sftp ls darkhorn/ -> users.csv present"
  else fail "sftp: $out"; fi
else
  echo "  [SKIP] sshpass/sftp not found — skipping SFTP check"
fi

# -- SOAP --------------------------------------------------------------------------
echo ""
echo "SOAP  http://$IP:3002"

wait_for "http://$IP:3002/soap?wsdl" || { fail "SOAP not reachable after 60s"; }

out=$(curl -sf "http://$IP:3002/soap?wsdl" 2>&1) || true
if echo "$out" | grep -qi "wsdl"; then ok "GET /soap?wsdl -> WSDL reachable"
else fail "GET /soap?wsdl: $out"; fi

envelope='<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tns="http://darkhorn.local/userservice"><soapenv:Header><wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsse:UsernameToken><wsse:Username>banshee</wsse:Username><wsse:Password>B4nsh33Sc4ms!</wsse:Password></wsse:UsernameToken></wsse:Security></soapenv:Header><soapenv:Body><tns:GetGroupsRequest/></soapenv:Body></soapenv:Envelope>'
out=$(curl -sf -X POST "http://$IP:3002/soap" \
  -H 'Content-Type: text/xml' \
  -H 'SOAPAction: ""' \
  -d "$envelope" 2>&1) || true
if echo "$out" | grep -q "GetGroupsResponse"; then ok "SOAP GetGroups -> ok"
else fail "SOAP GetGroups: $out"; fi

# -- MQ ----------------------------------------------------------------------------
echo ""
echo "MQ    $IP:5672 / mgmt $IP:15672"

out=$(curl -sf -u 'darkhorn:Wr41thPuls3!' "http://$IP:15672/api/healthchecks/node" 2>&1) || true
if echo "$out" | grep -q '"status".*"ok"'; then ok "RabbitMQ node health -> ok"
else fail "RabbitMQ health: $out"; fi

out=$(curl -sf -u 'darkhorn:Wr41thPuls3!' "http://$IP:15672/api/queues/%2F/darkhorn.requests" 2>&1) || true
if echo "$out" | grep -q "darkhorn.requests"; then ok "queue darkhorn.requests exists"
else fail "queue check: $out"; fi

# -- Summary -----------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ]

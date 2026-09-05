# darkhorn/scripts/test-from-host.ps1
# Smoke-tests all six darkhorn backends from the Windows host via vagrant ssh.
# Uploads a bash script to the VM and runs it there against 10.10.10.20.
#
# Usage: cd darkhorn; .\scripts\test-from-host.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Upload the test script to the VM and run it ───────────────────────────────
$bash = @'
#!/bin/bash
set -euo pipefail

IP="10.10.10.20"
PASS=0
FAIL=0

ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

# Install sshpass if missing
if ! command -v sshpass &>/dev/null; then
  sudo apt-get install -y -qq sshpass 2>/dev/null
fi

# ── REST ──────────────────────────────────────────────────────────────────────
echo ""
echo "REST  http://$IP:3000"

out=$(curl -sf "http://$IP:3000/api/health" 2>&1) || true
if echo "$out" | grep -q '"status".*"ok"'; then ok "GET /api/health -> ok"
else fail "GET /api/health: $out"; fi

out=$(curl -sf -X POST "http://$IP:3000/oauth/token" \
  -d 'grant_type=client_credentials&client_id=voidhorn&client_secret=v01dh0rn$3cr3t!' 2>&1) || true
if echo "$out" | grep -q "access_token"; then ok "POST /oauth/token -> token obtained"
else fail "POST /oauth/token: $out"; fi

out=$(curl -sf "http://$IP:3000/api/users" -u 'grimreaper:Wh1sp3r0fD4rk!' 2>&1) || true
if echo "$out" | grep -q '"total"'; then ok "GET /api/users (Basic Auth) -> ok"
else fail "GET /api/users: $out"; fi

# ── JDBC ──────────────────────────────────────────────────────────────────────
echo ""
echo "JDBC  $IP:5432"

out=$(PGPASSWORD='darkhorn' psql -h "$IP" -p 5432 -U darkhorn -d darkhorn_jdbc -tAc 'SELECT COUNT(*) FROM users;' 2>&1) || true
count=$(echo "$out" | grep -E '^[0-9]+$' | head -1)
if [ -n "$count" ]; then ok "SELECT COUNT(*) FROM users -> $count rows"
else fail "psql: $out"; fi

# ── LDAP ──────────────────────────────────────────────────────────────────────
echo ""
echo "LDAP  $IP:389"

count=$(ldapsearch -x -H "ldap://$IP:389" \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Users,dc=darkhorn,dc=local' \
  '(objectClass=inetOrgPerson)' dn 2>&1 | grep -c '^dn:') || true
if [ "$count" -gt 0 ] 2>/dev/null; then ok "ldapsearch inetOrgPerson -> $count entries"
else fail "ldapsearch returned $count entries"; fi

# ── SFTP ──────────────────────────────────────────────────────────────────────
echo ""
echo "SFTP  $IP:2222"

out=$(sshpass -p 'Sp3ctr4lF1l3!' sftp -o StrictHostKeyChecking=no -P 2222 \
  "spectral@$IP" <<< 'ls darkhorn' 2>&1) || true
if echo "$out" | grep -q "users.csv"; then ok "sftp ls darkhorn/ -> users.csv present"
else fail "sftp: $out"; fi

# ── SOAP ──────────────────────────────────────────────────────────────────────
echo ""
echo "SOAP  http://$IP:3002"

out=$(curl -sf "http://$IP:3002/soap?wsdl" 2>&1) || true
if echo "$out" | grep -qi "wsdl"; then ok "GET /soap?wsdl -> WSDL reachable"
else fail "GET /soap?wsdl: $out"; fi

envelope='<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dark="http://darkhorn.local/soap"><soapenv:Header><wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><wsse:UsernameToken><wsse:Username>banshee</wsse:Username><wsse:Password>B4nsh33Sc4ms!</wsse:Password></wsse:UsernameToken></wsse:Security></soapenv:Header><soapenv:Body><dark:GetGroups/></soapenv:Body></soapenv:Envelope>'
out=$(curl -sf -X POST "http://$IP:3002/soap" \
  -H 'Content-Type: text/xml' \
  -H 'SOAPAction: ""' \
  -d "$envelope" 2>&1) || true
if echo "$out" | grep -q "GetGroupsResponse"; then ok "SOAP GetGroups -> ok"
else fail "SOAP GetGroups: $out"; fi

# ── MQ ────────────────────────────────────────────────────────────────────────
echo ""
echo "MQ    $IP:5672 / mgmt $IP:15672"

out=$(curl -sf -u 'darkhorn:Wr41thPuls3!' "http://$IP:15672/api/healthchecks/node" 2>&1) || true
if echo "$out" | grep -q '"status".*"ok"'; then ok "RabbitMQ node health -> ok"
else fail "RabbitMQ health: $out"; fi

out=$(curl -sf -u 'darkhorn:Wr41thPuls3!' "http://$IP:15672/api/queues/%2F/darkhorn.requests" 2>&1) || true
if echo "$out" | grep -q "darkhorn.requests"; then ok "queue darkhorn.requests exists"
else fail "queue check: $out"; fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""
[ "$FAIL" -eq 0 ]
'@

$tmpLocal  = [System.IO.Path]::GetTempFileName() + ".sh"
$tmpRemote = "/tmp/darkhorn-test.sh"

[System.IO.File]::WriteAllText($tmpLocal, ($bash -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "Uploading test script to VM..." -ForegroundColor Cyan
vagrant upload $tmpLocal $tmpRemote
Remove-Item $tmpLocal

Write-Host "Running tests inside VM..." -ForegroundColor Cyan
vagrant ssh -c "bash $tmpRemote"

# darkhorn/scripts/test-from-host.ps1
# Smoke-tests all six darkhorn backends from the Windows host via vagrant ssh.
# Each check connects to 10.10.10.20:<port> from inside the VM.
#
# Usage: cd darkhorn; .\scripts\test-from-host.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$IP = "10.10.10.20"
$pass = 0
$fail = 0

function Ok   ($msg) { Write-Host "  [OK]   $msg" -ForegroundColor Green;  $script:pass++ }
function Fail ($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:fail++ }

function Ssh ($cmd) {
    vagrant ssh -c $cmd 2>&1
}

# ── REST ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "REST  http://$IP:3000" -ForegroundColor Yellow

try {
    $out = Ssh "curl -sf http://$IP:3000/api/health"
    if ($out -match '"status"\s*:\s*"ok"') { Ok "GET /api/health -> ok" }
    else                                   { Fail "unexpected response: $out" }
} catch { Fail "error: $_" }

try {
    $out = Ssh "curl -sf -X POST http://$IP:3000/oauth/token -d 'grant_type=client_credentials&client_id=voidhorn&client_secret=v01dh0rn`$3cr3t!'"
    if ($out -match "access_token") { Ok "POST /oauth/token -> token obtained" }
    else                            { Fail "no token in response: $out" }
} catch { Fail "error: $_" }

try {
    $out = Ssh "curl -sf http://$IP:3000/api/users -u 'grimreaper:Wh1sp3r0fD4rk!'"
    if ($out -match '"total"') { Ok "GET /api/users (Basic Auth) -> ok" }
    else                       { Fail "unexpected response: $out" }
} catch { Fail "error: $_" }

# ── JDBC ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "JDBC  $IP:5432" -ForegroundColor Yellow

try {
    $out = Ssh "PGPASSWORD='darkhorn' psql -h $IP -p 5432 -U darkhorn -d darkhorn_jdbc -tAc 'SELECT COUNT(*) FROM users;'"
    $count = ($out | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1).Trim()
    if ($count -match '^\d+$') { Ok "SELECT COUNT(*) FROM users -> $count rows" }
    else                       { Fail "unexpected output: $out" }
} catch { Fail "error: $_" }

# ── LDAP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "LDAP  $IP:389" -ForegroundColor Yellow

try {
    $out = Ssh "ldapsearch -x -H ldap://$IP:389 -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' -w 'Sp3ctr3Qu13t!' -b 'ou=Users,dc=darkhorn,dc=local' '(objectClass=inetOrgPerson)' dn 2>&1 | grep -c '^dn:'"
    $count = ($out | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1).Trim()
    if ($count -match '^\d+$') { Ok "ldapsearch inetOrgPerson -> $count entries" }
    else                       { Fail "unexpected output: $out" }
} catch { Fail "error: $_" }

# ── SFTP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "SFTP  $IP:2222" -ForegroundColor Yellow

try {
    $out = Ssh "sshpass -p 'Sp3ctr4lF1l3!' sftp -o StrictHostKeyChecking=no -P 2222 spectral@$IP <<< 'ls darkhorn'"
    if ($out -match "users\.csv") { Ok "sftp ls darkhorn/ -> users.csv present" }
    else                          { Fail "users.csv not found. Output: $out" }
} catch { Fail "error: $_" }

# ── SOAP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "SOAP  http://$IP:3002" -ForegroundColor Yellow

try {
    $out = Ssh "curl -sf 'http://$IP:3002/soap?wsdl'"
    if ($out -match "wsdl") { Ok "GET /soap?wsdl -> WSDL reachable" }
    else                    { Fail "unexpected response: $out" }
} catch { Fail "error: $_" }

try {
    $envelope = '<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:dark=\"http://darkhorn.local/soap\"><soapenv:Header><wsse:Security xmlns:wsse=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><wsse:UsernameToken><wsse:Username>banshee</wsse:Username><wsse:Password>B4nsh33Sc4ms!</wsse:Password></wsse:UsernameToken></wsse:Security></soapenv:Header><soapenv:Body><dark:GetGroups/></soapenv:Body></soapenv:Envelope>'
    $out = Ssh "curl -sf -X POST http://$IP:3002/soap -H 'Content-Type: text/xml' -H 'SOAPAction: \"\"' -d '$envelope'"
    if ($out -match "GetGroupsResponse") { Ok "SOAP GetGroups -> response ok" }
    else                                 { Fail "unexpected response: $out" }
} catch { Fail "error: $_" }

# ── MQ ────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "MQ    $IP:5672 / mgmt $IP:15672" -ForegroundColor Yellow

try {
    $out = Ssh "curl -sf -u 'darkhorn:Wr41thPuls3!' http://$IP:15672/api/healthchecks/node"
    if ($out -match '"status"\s*:\s*"ok"') { Ok "RabbitMQ node health -> ok" }
    else                                   { Fail "unexpected response: $out" }
} catch { Fail "error: $_" }

try {
    $out = Ssh "curl -sf -u 'darkhorn:Wr41thPuls3!' http://$IP:15672/api/queues/%2F/darkhorn.requests"
    if ($out -match "darkhorn\.requests") { Ok "queue darkhorn.requests exists" }
    else                                  { Fail "queue not found: $out" }
} catch { Fail "error: $_" }

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
Write-Host ""
if ($fail -gt 0) { exit 1 }

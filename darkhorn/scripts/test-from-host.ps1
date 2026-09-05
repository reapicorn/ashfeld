# darkhorn/scripts/test-from-host.ps1
# Smoke-tests all six darkhorn backends from the Windows host.
# Forwards ports via SSH to the Vagrant VM, runs one check per service, then tears down.
#
# Usage: cd darkhorn; .\scripts\test-from-host.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Ports to forward (host -> guest) ─────────────────────────────────────────
$forwards = @(
    "3000:localhost:3000",   # REST
    "5432:localhost:5432",   # JDBC (PostgreSQL)
    "3890:localhost:389",    # LDAP  (389 is privileged on host, use 3890)
    "2223:localhost:22",     # SFTP  (2220 is Vagrant SSH, use 2223)
    "3002:localhost:3002",   # SOAP
    "5672:localhost:5672",   # MQ AMQP
    "15672:localhost:15672"  # RabbitMQ mgmt
)

$sshArgs = ($forwards | ForEach-Object { "-L $_" }) -join " "

Write-Host ""
Write-Host "Opening SSH tunnels to darkhorn VM..." -ForegroundColor Cyan
$tunnel = Start-Process -FilePath "vagrant" `
    -ArgumentList "ssh -- $sshArgs -N -o ExitOnForwardFailure=yes" `
    -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3

$pass = 0
$fail = 0

function Ok   ($msg) { Write-Host "  [OK]   $msg" -ForegroundColor Green;  $script:pass++ }
function Fail ($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:fail++ }

# ── REST ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "REST  http://localhost:3000" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod "http://localhost:3000/api/health" -TimeoutSec 5
    if ($r.status -eq "ok") { Ok "health check -> status: ok" }
    else                    { Fail "health check returned: $($r | ConvertTo-Json -Compress)" }
} catch { Fail "health check error: $_" }

try {
    $token = (Invoke-RestMethod "http://localhost:3000/oauth/token" -Method POST `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "grant_type=client_credentials&client_id=voidhorn&client_secret=v01dh0rn%24%33cr3t!" `
        -TimeoutSec 5).access_token
    if ($token) { Ok "OIDC token (client_credentials) obtained" }
    else        { Fail "OIDC token empty" }
} catch { Fail "OIDC token error: $_" }

try {
    $headers = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("grimreaper:Wh1sp3r0fD4rk!")) }
    $users = Invoke-RestMethod "http://localhost:3000/api/users" -Headers $headers -TimeoutSec 5
    Ok "GET /api/users -> $($users.total) users"
} catch { Fail "GET /api/users error: $_" }

# ── JDBC (PostgreSQL) ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "JDBC  localhost:5432 (darkhorn_jdbc)" -ForegroundColor Yellow
try {
    $result = vagrant ssh -c "PGPASSWORD='Sp3ct3r0fN1ght!' psql -h localhost -U darkhorn -d darkhorn_jdbc -tAc 'SELECT COUNT(*) FROM users;'" 2>&1
    $count = ($result | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1).Trim()
    if ($count -match '^\d+$') { Ok "SELECT COUNT(*) FROM users -> $count rows" }
    else                       { Fail "unexpected output: $result" }
} catch { Fail "query error: $_" }

# ── LDAP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "LDAP  localhost:3890" -ForegroundColor Yellow
try {
    $result = vagrant ssh -c "ldapsearch -x -H ldap://localhost:389 -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' -w 'Sp3ctr3Qu13t!' -b 'ou=Users,dc=darkhorn,dc=local' '(objectClass=inetOrgPerson)' dn 2>&1 | grep -c '^dn:'" 2>&1
    $count = ($result | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1).Trim()
    if ($count -match '^\d+$') { Ok "ldapsearch inetOrgPerson -> $count entries" }
    else                       { Fail "unexpected output: $result" }
} catch { Fail "ldapsearch error: $_" }

# ── SFTP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "SFTP  localhost:2223" -ForegroundColor Yellow
try {
    $result = vagrant ssh -c "sshpass -p 'Sp3ctr4lF1l3!' sftp -o StrictHostKeyChecking=no -P 2222 spectral@localhost <<< 'ls darkhorn'" 2>&1
    if ($result -match "users\.csv") { Ok "SFTP ls darkhorn/ -> users.csv present" }
    else                             { Fail "users.csv not found. Output: $result" }
} catch { Fail "SFTP error: $_" }

# ── SOAP ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "SOAP  http://localhost:3002" -ForegroundColor Yellow
try {
    $wsdl = Invoke-WebRequest "http://localhost:3002/soap?wsdl" -TimeoutSec 5
    if ($wsdl.StatusCode -eq 200 -and $wsdl.Content -match "wsdl") { Ok "WSDL reachable (${($wsdl.Content.Length)} bytes)" }
    else { Fail "WSDL status: $($wsdl.StatusCode)" }
} catch { Fail "WSDL error: $_" }

try {
    $envelope = @"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:dark="http://darkhorn.local/soap">
  <soapenv:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <wsse:UsernameToken>
        <wsse:Username>banshee</wsse:Username>
        <wsse:Password>B4nsh33Sc4ms!</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soapenv:Header>
  <soapenv:Body>
    <dark:GetGroups/>
  </soapenv:Body>
</soapenv:Envelope>
"@
    $resp = Invoke-RestMethod "http://localhost:3002/soap" -Method POST `
        -ContentType "text/xml; charset=utf-8" `
        -Headers @{ SOAPAction = '""' } `
        -Body $envelope -TimeoutSec 5
    Ok "GetGroups SOAP call succeeded"
} catch { Fail "GetGroups SOAP error: $_" }

# ── MQ ────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "MQ    http://localhost:15672 (RabbitMQ mgmt)" -ForegroundColor Yellow
try {
    $r = Invoke-RestMethod "http://localhost:15672/api/healthchecks/node" `
        -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("darkhorn:Wr41thPuls3!")) } `
        -TimeoutSec 5
    if ($r.status -eq "ok") { Ok "RabbitMQ node health -> ok" }
    else                    { Fail "RabbitMQ health: $($r | ConvertTo-Json -Compress)" }
} catch { Fail "RabbitMQ mgmt error: $_" }

try {
    $q = Invoke-RestMethod "http://localhost:15672/api/queues/%2F/darkhorn.requests" `
        -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("darkhorn:Wr41thPuls3!")) } `
        -TimeoutSec 5
    Ok "Queue darkhorn.requests exists (messages ready: $($q.messages_ready))"
} catch { Fail "Queue check error: $_" }

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Closing SSH tunnels..." -ForegroundColor Cyan
Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
Write-Host ""
if ($fail -gt 0) { exit 1 }

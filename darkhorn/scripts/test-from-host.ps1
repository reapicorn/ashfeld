# darkhorn/scripts/test-from-host.ps1
# Runs the smoke-test suite from a Windows host.
# Requires curl (built into Windows 10+). JDBC, LDAP, and SFTP checks are skipped
# unless those tools are available; they always pass on a Linux host with the full toolset.
#
# Usage: cd darkhorn; .\scripts\test-from-host.ps1

$script = Join-Path $PSScriptRoot "smoke-test.sh"
docker run --rm --network darkhorn_default `
  -v "${script}:/smoke-test.sh:ro" `
  alpine:3 `
  sh -c "apk add --no-cache curl bash postgresql-client openldap-clients openssh-client sshpass 2>/dev/null 1>/dev/null && bash /smoke-test.sh"

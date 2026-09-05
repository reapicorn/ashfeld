# darkhorn/scripts/test-from-host.ps1
# Runs the smoke-test suite from the Windows host via vagrant ssh.
# The actual test logic lives in scripts/smoke-test.sh (runs inside the VM).
#
# Usage: cd darkhorn; .\scripts\test-from-host.ps1

vagrant ssh -c "bash /vagrant/scripts/smoke-test.sh"

# tests/smoke-test.ps1
# Destroys and re-provisions all Ashfeld VMs, verifying each vagrant up exits successfully.
#
# Usage: pwsh tests/smoke-test.ps1

$root = Split-Path $PSScriptRoot -Parent
$PASS = 0
$FAIL = 0

$vms = @(
    @{ label = "Ironhold";    dir = "$root\ironhold" }
    @{ label = "Darkhorn";    dir = "$root\darkhorn" }
    @{ label = "Hollowcrown"; dir = "$root\hollowcrown" }
    @{ label = "Thorngate";   dir = "$root\thorngate" }
)

# Phase 1 — destroy all
Write-Host ""
Write-Host "Phase 1 - destroy all" -ForegroundColor Cyan
foreach ($vm in $vms) {
    Push-Location $vm.dir
    vagrant destroy -f 2>&1 | Tee-Object -FilePath (Join-Path $vm.dir "vagrant.log")
    Pop-Location
}

# Phase 2 — up all
Write-Host ""
Write-Host "Phase 2 - up all" -ForegroundColor Cyan
foreach ($vm in $vms) {
    Write-Host ""
    Write-Host $vm.label -ForegroundColor Cyan
    $log = Join-Path $vm.dir "vagrant.log"
    Push-Location $vm.dir
    vagrant up 2>&1 | Tee-Object -FilePath $log -Append
    $exit = $LASTEXITCODE
    Pop-Location
    if ($exit -eq 0) {
        Write-Host "  [OK]   $($vm.label) - vagrant up succeeded" -ForegroundColor Green
        $PASS++
    } else {
        Write-Host "  [FAIL] $($vm.label) - vagrant up exited with code $exit (see $log)" -ForegroundColor Red
        $FAIL++
    }
}

# Phase 3 — destroy all
Write-Host ""
Write-Host "Phase 3 - destroy all" -ForegroundColor Cyan
foreach ($vm in $vms) {
    Push-Location $vm.dir
    vagrant destroy -f 2>&1 | Tee-Object -FilePath (Join-Path $vm.dir "vagrant.log") -Append
    Pop-Location
}

Write-Host ""
Write-Host "Results: $PASS passed, $FAIL failed"
Write-Host ""
exit $FAIL

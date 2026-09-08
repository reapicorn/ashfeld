# tests/smoke-test.ps1
# Destroys and re-provisions all Ashfeld VMs, verifying each vagrant up exits successfully.
#
# Usage (foreground): pwsh tests/smoke-test.ps1
# Usage (background): Start-Process pwsh -ArgumentList "-File tests/smoke-test.ps1" -RedirectStandardOutput tests/smoke-test.log -RedirectStandardError tests/smoke-test.log -NoNewWindow

param(
    [string]$Log = "$PSScriptRoot\smoke-test.log"
)

$root  = Split-Path $PSScriptRoot -Parent
$PASS  = 0
$FAIL  = 0
$start = Get-Date

# All output goes to both the console and the log file
function log {
    param($msg, $color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $Log -Value $line
}

# Truncate log at start
"" | Set-Content -Path $Log

$vms = @(
    @{ label = "EMBERCRYPT";    dir = "$root\EMBERCRYPT" }
    @{ label = "Darkhorn";    dir = "$root\darkhorn" }
    @{ label = "Hollowcrown"; dir = "$root\hollowcrown" }
    @{ label = "Thorngate";   dir = "$root\Thorngate" }
)

function run-vagrant {
    param($dir, $cmd, $logFile)
    Push-Location $dir
    & vagrant $cmd 2>&1 | Tee-Object -FilePath $logFile -Append | ForEach-Object {
        $ts = Get-Date -Format "HH:mm:ss"
        $line = "[$ts] $_"
        Write-Host $line
        Add-Content -Path $Log -Value $line
    }
    $exit = $LASTEXITCODE
    Pop-Location
    return $exit
}

# Phase 1 - destroy all
log ""
log "Phase 1 - destroy all" Cyan
foreach ($vm in $vms) {
    log "$($vm.label) - destroying..." Cyan
    run-vagrant $vm.dir @("destroy", "-f") (Join-Path $vm.dir "vagrant.log") | Out-Null
}

# Phase 2 - up all
log ""
log "Phase 2 - up all" Cyan
foreach ($vm in $vms) {
    log ""
    log "$($vm.label) - starting..." Cyan
    $vagrantLog = Join-Path $vm.dir "vagrant.log"
    $exit = run-vagrant $vm.dir @("up") $vagrantLog
    if ($exit -eq 0) {
        log "  [OK]   $($vm.label) - vagrant up succeeded" Green
        $PASS++
    } else {
        log "  [FAIL] $($vm.label) - vagrant up exited with code $exit (see $vagrantLog)" Red
        $FAIL++
    }
}

# Phase 3 - destroy all
log ""
log "Phase 3 - destroy all" Cyan
foreach ($vm in $vms) {
    log "$($vm.label) - destroying..." Cyan
    run-vagrant $vm.dir @("destroy", "-f") (Join-Path $vm.dir "vagrant.log") | Out-Null
}

$elapsed = (Get-Date) - $start
$duration = "{0:hh\:mm\:ss}" -f $elapsed

log ""
log "Results: $PASS passed, $FAIL failed - duration: $duration" $(if ($FAIL -eq 0) { "Green" } else { "Red" })
log ""
exit $FAIL

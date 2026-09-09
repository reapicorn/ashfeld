# tests/smoke-test.ps1
# Destroys and re-provisions Ashfeld VMs, verifying each vagrant up exits successfully.
#
# Usage (all VMs):    pwsh tests/smoke-test.ps1
# Usage (single VM):  pwsh tests/smoke-test.ps1 -VM darkhorn
# Usage (background): Start-Process pwsh -ArgumentList "-File tests/smoke-test.ps1" -RedirectStandardOutput tests/smoke-test.log -RedirectStandardError tests/smoke-test.log -NoNewWindow

param(
    [string]$Log = "$PSScriptRoot\smoke-test.log",
    [string]$VM  = ""
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

$allVms = @(
    @{ label = "Embercrypt";    dir = "$root\Embercrypt" }
    @{ label = "Darkhorn";      dir = "$root\darkhorn" }
    @{ label = "Hollowcrown";   dir = "$root\hollowcrown" }
    @{ label = "Stonewrit";     dir = "$root\stonewrit" }
    @{ label = "Warden's Post"; dir = "$root\wardens-post" }
)

if ($VM -ne "") {
    $vms = [System.Collections.ArrayList]@()
    foreach ($v in $allVms) {
        if ($v.label -eq $VM -or $v.dir -like "*\$VM") { [void]$vms.Add($v) }
    }
    if ($vms.Count -eq 0) {
        $labels = ($allVms | ForEach-Object { $_.label }) -join ', '
        Write-Host "Unknown VM: '$VM'. Valid values: $labels" -ForegroundColor Red
        exit 1
    }
} else {
    $vms = $allVms
}

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
foreach ($entry in $vms) {
    log "$($entry.label) - destroying..." Cyan
    run-vagrant $entry.dir @("destroy", "-f") (Join-Path $entry.dir "vagrant.log") | Out-Null
}

# Phase 2 - up all
log ""
log "Phase 2 - up all" Cyan
foreach ($entry in $vms) {
    log ""
    log "$($entry.label) - starting..." Cyan
    $vagrantLog = Join-Path $entry.dir "vagrant.log"
    $exit = run-vagrant $entry.dir @("up") $vagrantLog
    if ($exit -eq 0) {
        log "  [OK]   $($entry.label) - vagrant up succeeded" Green
        $PASS++
    } else {
        log "  [FAIL] $($entry.label) - vagrant up exited with code $exit (see $vagrantLog)" Red
        $FAIL++
    }
}

# Phase 3 - destroy all
log ""
log "Phase 3 - destroy all" Cyan
foreach ($entry in $vms) {
    log "$($entry.label) - destroying..." Cyan
    run-vagrant $entry.dir @("destroy", "-f") (Join-Path $entry.dir "vagrant.log") | Out-Null
}

$elapsed = (Get-Date) - $start
$duration = "{0:hh\:mm\:ss}" -f $elapsed

log ""
log "Results: $PASS passed, $FAIL failed - duration: $duration" $(if ($FAIL -eq 0) { "Green" } else { "Red" })
log ""
exit $FAIL

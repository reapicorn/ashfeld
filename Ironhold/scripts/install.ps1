# =============================================================
#  Secret Server Lab - Installation Script
#  Runs automatically via Vagrant (SSH) on "vagrant up"
#
#  Idempotent: safe to re-run via "vagrant provision"
#
#  To run only specific steps (comma-separated):
#    vagrant provision --provision-with install
#    C:\sslab\install.ps1 -Steps "sql_db,ss_install"
#
#  Install steps:
#    serviceaccount        Create local service account
#    serviceaccount_admin  Add service account to Administrators
#    choco                 Install Chocolatey
#    sql_install           Install SQL Server Express
#    sql_auth              Enable mixed-mode authentication
#    sql_db                Create SecretServer DB + login + db_owner
#    tools                 Install Firefox, VS Code, PowerShell 7
#    iis_cert              Create self-signed cert + HTTPS binding
#    ss_install            Run ISVPsetup.exe silent install (default)
#    ss_extract            Extract ss_update.zip to wwwroot/SecretServer (alternative)
#    ss_apppool            Create and configure SecretServer App Pool
#    ss_iisapp             Register /SecretServer as IIS application
#
#  Uninstall steps (only when explicitly specified):
#    uninstall_secretserver   Remove SS files, IIS app/pool, registry, DB, login
#    uninstall_iis            Remove IIS features, HTTPS binding, cert
#    uninstall_sql_db         Drop SecretServer DB and login only
#    uninstall_sql            Uninstall SQL Server Express
#    uninstall_choco          Uninstall Chocolatey
#    uninstall_serviceaccount Remove svc_ss from Administrators and delete user
#    uninstall_firewall       Remove SecretServer firewall rules
# =============================================================
param(
    [string]$ServiceUser   = "svc_ss",
    [string]$ServicePass   = "Ir0nhold#Lab!",
    [string]$DbName        = "SecretServer",
    [string]$InstallMode   = "installer",   # "installer" = ISVPsetup.exe silent | "extract" = ss_update.zip
    [string]$Steps         = ""
)

$ErrorActionPreference = "Stop"
$LabDir         = "C:\sslab"
$LogFile        = "$LabDir\install.log"
$InstallDir     = "C:\inetpub\wwwroot\SecretServer"
$ServiceAccount = "$env:COMPUTERNAME\$ServiceUser"
$InstallerSrc   = "$LabDir\installer_src"

# -- Step resolution -------------------------------------------
$runAll   = [string]::IsNullOrWhiteSpace($Steps)
$stepList = $Steps -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
function ShouldRun { param([string]$name)
    if ($name -match "^uninstall_") { return $stepList -contains $name }
    return $runAll -or ($stepList -contains $name)
}

# -- Logging ---------------------------------------------------
New-Item -ItemType Directory -Force -Path $LabDir | Out-Null
function Log       { param($msg) $ts = Get-Date -Format "HH:mm:ss"; $line = "$ts  $msg"; try { $line | Add-Content -Path $LogFile } catch {}; Write-Host $line }
function Step      { param($msg) Log ""; Log "==> $msg" }
function RunSilent { param([scriptblock]$sb) & $sb 2>&1 | Add-Content -Path $LogFile }

# -- Progress tracking -----------------------------------------
$ssSteps = if ($InstallMode -eq "extract") {
    @("ss_extract","ss_apppool","ss_iisapp")
} else {
    @("ss_install","ss_apppool","ss_iisapp")
}
$allSteps = if ($InstallMode -eq "extract") {
    @(
        "serviceaccount","serviceaccount_admin",
        "choco",
        "sql_install","sql_auth","sql_db",
        "tools",
        "iis_cert"
    ) + $ssSteps
} else {
    @(
        "serviceaccount","serviceaccount_admin",
        "choco",
        "sql_install","sql_auth","sql_db",
        "tools"
    ) + $ssSteps + @("iis_cert")
}
$plannedSteps   = if ($runAll) { $allSteps } else { $stepList | Where-Object { $_ -notmatch "^uninstall_" } }
$completedSteps = @()

function PrintPlan {
    if ($plannedSteps.Count -eq 0) { return }
    Log "Progress:"
    foreach ($s in $allSteps) {
        if ($plannedSteps -contains $s) {
            if ($completedSteps -contains $s) { Log "  [x] $s" } else { Log "  [ ] $s" }
        }
    }
}
function Done { param($name) $script:completedSteps += $name; PrintPlan }

# -- Banner ----------------------------------------------------
Step "Starting Secret Server lab installation"
if ($runAll) { Log "Running steps: all" } else { Log "Running steps: $($stepList -join ', ')" }
PrintPlan

# ==============================================================
# INSTALL STEPS
# ==============================================================

# -- serviceaccount: Create local user -------------------------
if (ShouldRun "serviceaccount") {
    Step "Service account - create"
    if (-not (Get-LocalUser -Name $ServiceUser -ErrorAction SilentlyContinue)) {
        $secPw = ConvertTo-SecureString $ServicePass -AsPlainText -Force
        New-LocalUser -Name $ServiceUser -Password $secPw -PasswordNeverExpires | Out-Null
        Log "Created local user: $ServiceAccount"
    } else {
        Log "Local user already exists: $ServiceAccount"
    }
    Done "serviceaccount"
}

# -- serviceaccount_admin: Add to Administrators ---------------
if (ShouldRun "serviceaccount_admin") {
    Step "Service account - add to Administrators"
    if (-not (Get-LocalGroupMember -Group "Administrators" -Member $ServiceUser -ErrorAction SilentlyContinue)) {
        Add-LocalGroupMember -Group "Administrators" -Member $ServiceUser
        Log "Added $ServiceUser to Administrators."
    } else {
        Log "$ServiceUser is already in Administrators."
    }
    Done "serviceaccount_admin"
}

# -- choco: Install Chocolatey ---------------------------------
if (ShouldRun "choco") {
    Step "Chocolatey"
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        & ([scriptblock]::Create((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))) 2>&1 | Add-Content -Path $LogFile
        Log "Chocolatey installed."
    } else {
        Log "Chocolatey already installed."
    }
    Done "choco"
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# -- sql_install: Install SQL Server Express -------------------
if (ShouldRun "sql_install") {
    Step "SQL Server Express - install"
    if (-not (Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue)) {
        RunSilent { choco install sql-server-express -y --no-progress 2>&1 }
        Log "SQL Server Express installed."
    } else {
        Log "SQL Server Express already installed."
    }
    Done "sql_install"
}

# -- Discover sqlcmd path across all SQL Server versions -------
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Get-ChildItem "C:\Program Files\Microsoft SQL Server" -ErrorAction SilentlyContinue |
    Where-Object { $_.PSIsContainer } |
    ForEach-Object {
        $bin = Join-Path $_.FullName "Tools\Binn"
        if (Test-Path $bin) { $env:Path += ";$bin" }
    }

# -- sql_auth: Enable mixed-mode authentication ----------------
if (ShouldRun "sql_auth") {
    Step "SQL Server - mixed-mode auth"
    $regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server"
    $instance = Get-ChildItem $regPath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match "^MSSQL\d+\.SQLEXPRESS$" } | Select-Object -First 1
    $currentMode = if ($instance) {
        (Get-ItemProperty -Path "$regPath\$($instance.PSChildName)\MSSQLServer" -Name "LoginMode" -ErrorAction SilentlyContinue).LoginMode
    } else { $null }

    if ($currentMode -ne 2) {
        $sql = @"
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
     N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
GO
"@
        $sql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Add-Content -Path $LogFile
        Restart-Service -Name "MSSQL`$SQLEXPRESS" -Force
        # Wait until SQL Server is ready to accept connections
        $timeout = 180
        $elapsed = 0
        do {
            Start-Sleep -Seconds 5
            $elapsed += 5
            $ready = sqlcmd -S "localhost\SQLEXPRESS" -E -Q "SELECT 1" 2>&1
        } while ($ready -notmatch "---" -and $elapsed -lt $timeout)
        if ($elapsed -ge $timeout) { Log "WARN: SQL Server did not respond within $timeout seconds." }
        else { Log "SQL Server ready after $elapsed seconds." }
        Log "Mixed-mode auth enabled and SQL Server restarted."
    } else {
        Log "Mixed-mode auth already enabled."
    }
    Done "sql_auth"
}

# -- sql_db: Create database, login, db_owner ------------------
if (ShouldRun "sql_db") {
    Step "SQL Server - create DB and login"
    $sql = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$ServiceAccount')
    CREATE LOGIN [$ServiceAccount] FROM WINDOWS;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$DbName')
    CREATE DATABASE [$DbName] COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE [$DbName];
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'$ServiceAccount')
    CREATE USER [$ServiceAccount] FOR LOGIN [$ServiceAccount];

IF IS_ROLEMEMBER(N'db_owner', N'$ServiceAccount') <> 1
    ALTER ROLE [db_owner] ADD MEMBER [$ServiceAccount];
GO
"@
    $sql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Add-Content -Path $LogFile
    Log "Database '$DbName' and login '$ServiceAccount' configured."
    Done "sql_db"
}

# -- tools: Firefox, VS Code, PowerShell 7, bookmarks, taskbar -
if (ShouldRun "tools") {
    Step "Tools - Firefox, VS Code, PowerShell 7"

    if (-not (Test-Path "$env:ProgramFiles\Mozilla Firefox\firefox.exe")) {
        RunSilent { choco install firefox -y --no-progress 2>&1 }
        Log "Firefox installed."
    } else { Log "Firefox already installed." }

    if (-not (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")) {
        RunSilent { choco install vscode -y --no-progress 2>&1 }
        Log "VS Code installed."
    } else { Log "VS Code already installed." }

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        RunSilent { choco install powershell-core -y --no-progress 2>&1 }
        Log "PowerShell 7 installed."
    } else { Log "PowerShell 7 already installed." }

    # Firefox bookmark - loaded on first launch for every new profile
    $ffDist = "$env:ProgramFiles\Mozilla Firefox\distribution"
    New-Item -ItemType Directory -Force -Path $ffDist | Out-Null
    @"
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Toolbar</H1>
<DL><p>
    <DT><A HREF="http://localhost/SecretServer">Secret Server</A>
</DL><p>
"@ | Set-Content -Path "$ffDist\bookmarks.html" -Encoding UTF8
    Log "Firefox bookmark configured."

    # Taskbar - hide Search and Task View buttons (machine-wide, takes effect immediately)
    $explorerKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $explorerKey)) { New-Item -Path $explorerKey -Force | Out-Null }
    Set-ItemProperty -Path $explorerKey -Name "HideTaskViewButton" -Value 1 -Type DWord
    Log "Taskbar search and task view hidden."

    # First-logon script: taskbar pins + Firefox profile bookmark
    # These require an interactive user session - runs once at first logon of vagrant user
    $firstLogonScript = @'
# Apply taskbar pins via LayoutModification.xml
$layoutXml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%ProgramFiles%\Mozilla Firefox\firefox.exe" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="%windir%\system32\inetsrv\InetMgr.exe" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="%ProgramFiles%\Microsoft VS Code\Code.exe" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="%ProgramFiles%\PowerShell\7\pwsh.exe" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
$layoutPath = "C:\Windows\System32\LayoutModification.xml"
$layoutXml | Set-Content -Path $layoutPath -Encoding UTF8

# Hide search box
$searchKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
if (-not (Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
Set-ItemProperty -Path $searchKey -Name "SearchboxTaskbarMode" -Value 0 -Type DWord

# Restart Explorer to apply taskbar changes
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

# Firefox profile bookmark - copy to the default profile if it exists
$ffProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffProfiles) {
    Get-ChildItem $ffProfiles -Directory | ForEach-Object {
        $bookmarksDst = "$($_.FullName)\bookmarkbackups"
        # Force Firefox to import distribution bookmarks on next launch
        $placesDb = "$($_.FullName)\places.sqlite"
        if (Test-Path $placesDb) { Remove-Item $placesDb -Force -ErrorAction SilentlyContinue }
    }
}

# Self-delete this scheduled task
Unregister-ScheduledTask -TaskName "IronholdFirstLogon" -Confirm:$false -ErrorAction SilentlyContinue
'@
    $firstLogonPath = "$LabDir\firstlogon.ps1"
    $firstLogonScript | Set-Content -Path $firstLogonPath -Encoding UTF8

    # Register scheduled task to run at first logon of vagrant user
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$firstLogonPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "vagrant"
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName "IronholdFirstLogon" `
        -Action $action -Trigger $trigger -Settings $settings `
        -RunLevel Highest -Force | Out-Null
    Log "First-logon task registered (taskbar pins + Firefox bookmark)."

    Done "tools"
}

# -- ss_install: Silent install via ISVPsetup.exe --------------
if (ShouldRun "ss_install") {
    Step "Vault - silent install"
    $installer = "$InstallerSrc\ISVPsetup.exe"

    if (Test-Path "$InstallDir\web.config") {
        Log "Files already present - skipping install."
    } elseif (-not (Test-Path $installer)) {
        throw "ISVPsetup.exe not found at $installer. Place it in Ironhold/installer/ and re-run: vagrant provision"
    } else {
        # Note: /l path must be separate from install.log - the installer's internal
        # Launcher.ps1 opens the same log file and conflicts if it's already open.
        $prereqLog = "C:\sslab-prereqs.log"
        $appLog    = "C:\sslab-install.log"

        # Stage 1: install prerequisites (IIS, IIS components, WCF)
        # INSTALL_NetFx48 omitted - .NET 4.8 is already present on Windows Server 2025
        # INSTALL_HTTPS_BINDING omitted - we configure the cert separately via iis_cert
        Log "Stage 1: installing prerequisites... (log: $prereqLog)"
        $proc = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList @(
            "-q", "-s",
            "InstallPreReqs=1",
            "PRE_REQS_TO_INSTALL=INSTALL_IIS,INSTALL_IIS_COMPS,INSTALL_NET_WCF",
            "/l", $prereqLog
        )
        if ($proc.ExitCode -ne 0) {
            Log "WARN: Prerequisites installer exited with code $($proc.ExitCode). Check $prereqLog"
        } else {
            Log "Prerequisites installed (exit 0)."
        }

        # Stage 2: install the application
        Log "Stage 2: installing application... (log: $appLog)"
        $proc = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList @(
            "-q", "-s", "/nodetect",
            "InstallSecretServer=1",
            "SecretServerAppUserName=$ServiceAccount",
            "SecretServerAppPassword=$ServicePass",
            "SqlServer=localhost\SQLEXPRESS",
            "SqlDatabase=$DbName",
            "SqlUseSvcAccount=1",
            "/l", $appLog
        )
        if ($proc.ExitCode -ne 0) {
            Log "WARN: Application installer exited with code $($proc.ExitCode). Check $appLog"
        } else {
            Log "Application installed (exit 0)."
        }
    }
    Done "ss_install"
}

# -- ss_extract: Extract ss_update.zip to wwwroot/SecretServer -
if (ShouldRun "ss_extract") {
    Step "Secret Server - extract files"
    $ssUpdateZip = "$InstallerSrc\ss_update.zip"

    if (Test-Path "$InstallDir\web.config") {
        Log "SS files already present - skipping extraction."
    } elseif (-not (Test-Path $ssUpdateZip)) {
        throw "ss_update.zip not found at $ssUpdateZip. Place it in Ironhold/installer/ and re-run: vagrant provision"
    } else {
        $extractTemp = "$LabDir\ss_extract_temp"
        Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
        Expand-Archive -Path $ssUpdateZip -DestinationPath $extractTemp -Force
        Log "Extracted ss_update.zip."

        $webConfigInTemp = Get-ChildItem $extractTemp -Recurse -Filter "web.config" |
            Where-Object { $_.DirectoryName -notmatch "\\bin\\" } | Select-Object -First 1
        if (-not $webConfigInTemp) {
            Log "ERROR: web.config not found inside ss_update.zip."
            Remove-Item $extractTemp -Recurse -Force
        } else {
            $ssFilesRoot = $webConfigInTemp.DirectoryName
            New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
            Copy-Item "$ssFilesRoot\*" -Destination $InstallDir -Recurse -Force
            Remove-Item $extractTemp -Recurse -Force
            Log "SS files copied to $InstallDir"
        }

        if (-not (Test-Path "$InstallDir\web.config")) {
            Log "ERROR: web.config not found in $InstallDir after extraction."
        } else {
            Log "SS files extracted successfully."
        }
    }
    Done "ss_extract"
}

# -- iis_cert: Self-signed cert + HTTPS binding ----------------
if (ShouldRun "iis_cert") {
    Step "IIS HTTPS certificate"
    Import-Module WebAdministration
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match "CN=ironhold" } | Select-Object -First 1
    if (-not $cert) {
        $cert = New-SelfSignedCertificate -DnsName "ironhold" -CertStoreLocation "Cert:\LocalMachine\My"
        Log "Self-signed certificate created: $($cert.Thumbprint)"
    } else {
        Log "Self-signed certificate already exists: $($cert.Thumbprint)"
    }
    $existingBinding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -ErrorAction SilentlyContinue
    if (-not $existingBinding) {
        New-WebBinding -Name "Default Web Site" -Protocol "https" -Port 443 -IPAddress "*"
        $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https"
        $binding.AddSslCertificate($cert.Thumbprint, "My")
        Log "HTTPS binding added to Default Web Site."
    } else {
        $sslCert = Get-ChildItem "IIS:\SslBindings\0.0.0.0!443" -ErrorAction SilentlyContinue
        if (-not $sslCert) {
            $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https"
            $binding.AddSslCertificate($cert.Thumbprint, "My")
            Log "Certificate assigned to existing HTTPS binding."
        } else {
            Log "HTTPS binding already exists with certificate."
        }
    }
    Done "iis_cert"
}

# -- ss_apppool: Create and configure SecretServer App Pool ----
if (ShouldRun "ss_apppool") {
    Step "Secret Server - App Pool"
    Import-Module WebAdministration

    if (-not (Test-Path "IIS:\AppPools\SecretServer")) {
        New-WebAppPool -Name "SecretServer" | Out-Null
        Log "Created App Pool: SecretServer"
    }
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "managedRuntimeVersion"          -Value "v4.0"
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "managedPipelineMode"            -Value 0
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.userName"          -Value $ServiceAccount
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.password"          -Value $ServicePass
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.identityType"      -Value 3
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.loadUserProfile"   -Value $true
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.idleTimeout"       -Value ([TimeSpan]::Zero)
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "startMode"                      -Value "AlwaysRunning"
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "recycling.periodicRestart.time" -Value ([TimeSpan]::Zero)
    Log "App Pool SecretServer configured (identity: $ServiceAccount)"
    Done "ss_apppool"
}

# -- ss_iisapp: Register /SecretServer as IIS application ------
if (ShouldRun "ss_iisapp") {
    Step "Secret Server - IIS application"
    Import-Module WebAdministration

    $sitePath = (Get-ItemProperty "IIS:\Sites\Default Web Site").physicalPath
    if ($sitePath -ne "C:\inetpub\wwwroot") {
        Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "physicalPath" -Value "C:\inetpub\wwwroot"
        Log "Corrected Default Web Site physicalPath (was: $sitePath)"
    }

    $existingApp = & "$env:windir\system32\inetsrv\appcmd.exe" list app "Default Web Site/SecretServer" 2>&1
    if ($existingApp -notmatch "Default Web Site/SecretServer") {
        & "$env:windir\system32\inetsrv\appcmd.exe" add app `
            /site.name:"Default Web Site" `
            /path:"/SecretServer" `
            /physicalPath:$InstallDir `
            /applicationPool:"SecretServer" 2>&1 | Add-Content -Path $LogFile
        Log "Created IIS application: Default Web Site/SecretServer -> $InstallDir"
    } else {
        & "$env:windir\system32\inetsrv\appcmd.exe" set app "Default Web Site/SecretServer" `
            /physicalPath:$InstallDir `
            /applicationPool:"SecretServer" 2>&1 | Add-Content -Path $LogFile
        Log "IIS application updated: Default Web Site/SecretServer -> $InstallDir"
    }
    Done "ss_iisapp"
}

# -- Banner ----------------------------------------------------
Log ""
Log "========================================================"
Log "  Ironhold - Provisioning Complete"
Log "========================================================"
Log ""
Log "  NEXT STEP - Complete setup wizard from inside the VM:"
Log ""
Log "  Step 1 - Database setup:"
Log "    http://localhost/SecretServer/Setup/Database?FreshInstall=true"
Log "    SQL Server:   localhost\SQLEXPRESS"
Log "    Database:     $DbName"
Log "    Auth:         Windows Authentication"
Log ""
Log "  Step 2 - Create initial administrator:"
Log "    Username:     admin"
Log "    Display name: Admin"
Log "    Email:        admin@lab.local"
Log "    Password:     $ServicePass"
Log ""
Log "  Access (from host):"
Log "    HTTP:   http://localhost:8010/SecretServer"
Log "    HTTPS:  https://localhost:4430/SecretServer"
Log "========================================================"
Log ""

# ==============================================================
# UNINSTALL STEPS
# ==============================================================

# -- uninstall_secretserver ------------------------------------
if (ShouldRun "uninstall_secretserver") {
    Step "Uninstall - Secret Server"
    Import-Module WebAdministration

    $bundleKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{0cbbd63f-c6de-4472-b728-ce4bce1ff4b1}"
    $msiKey    = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{017DE4BA-E3D5-4293-909A-8CB41B3322AF}"
    foreach ($key in @($bundleKey, $msiKey)) {
        $entry = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($entry -and $entry.UninstallString -match "MsiExec") {
            $productCode = ($entry.UninstallString -replace ".*(/[IX])\{", "{") -replace "\}.*", "}"
            $proc = Start-Process "msiexec.exe" -ArgumentList "/x {$productCode} /qn /norestart" -Wait -PassThru
            Start-Sleep -Seconds 3
            $msi = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue
            if ($msi) { Log "Waiting for MSI uninstall..."; Wait-Process -Name "msiexec" }
            Log "Uninstalled: $($entry.DisplayName)"
        }
    }

    $depEntry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -eq "Thycotic.Installers.Dependencies" } | Select-Object -First 1
    if ($depEntry) {
        $proc = Start-Process "msiexec.exe" -ArgumentList "/x $($depEntry.PSChildName) /qn /norestart" -Wait -PassThru
        Start-Sleep -Seconds 3
        $msi = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue
        if ($msi) { Log "Waiting for Dependencies MSI..."; Wait-Process -Name "msiexec" }
        if ($proc.ExitCode -eq 1612) {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($depEntry.PSChildName)" -Recurse -Force -ErrorAction SilentlyContinue
            Log "Thycotic.Installers.Dependencies registry entry removed (exit 1612)."
        } else {
            Log "Uninstalled: Thycotic.Installers.Dependencies (exit: $($proc.ExitCode))"
        }
    }

    $registryKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\AB4ED7105D3E392409A9C84BB13322FA",
        "HKLM:\SOFTWARE\Classes\Installer\Products\AB4ED7105D3E392409A9C84BB13322FA",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{0cbbd63f-c6de-4472-b728-ce4bce1ff4b1}",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{017DE4BA-E3D5-4293-909A-8CB41B3322AF}",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{0cbbd63f-c6de-4472-b728-ce4bce1ff4b1}",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{017DE4BA-E3D5-4293-909A-8CB41B3322AF}",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\{017DE4BA-E3D5-4293-909A-8CB41B3322AF}",
        "HKLM:\SOFTWARE\Classes\Installer\Dependencies\{0cbbd63f-c6de-4472-b728-ce4bce1ff4b1}"
    )
    foreach ($key in $registryKeys) {
        if (Test-Path $key) { Remove-Item $key -Recurse -Force; Log "Removed registry key: $key" }
    }

    if (Get-WebApplication -Site "Default Web Site" -Name "SecretServer" -ErrorAction SilentlyContinue) {
        Remove-WebApplication -Site "Default Web Site" -Name "SecretServer"
        Log "IIS application /SecretServer removed."
    }
    if (Test-Path "IIS:\AppPools\SecretServer") {
        Stop-WebAppPool -Name "SecretServer" -ErrorAction SilentlyContinue
        Remove-WebAppPool -Name "SecretServer"
        Log "App Pool SecretServer removed."
    }

    $sitePool = (Get-ItemProperty "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue).applicationPool
    if ($sitePool -eq "SecretServer") {
        Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "applicationPool" -Value "DefaultAppPool"
        Log "Default Web Site app pool restored to DefaultAppPool."
    }

    if (Test-Path "C:\inetpub\wwwroot\SecretServer") {
        Remove-Item "C:\inetpub\wwwroot\SecretServer" -Recurse -Force
        Log "Install folder removed."
    }

    foreach ($dir in @(
        "C:\ProgramData\Package Cache\{017DE4BA-E3D5-4293-909A-8CB41B3322AF}v12.0.000022",
        "C:\ProgramData\Package Cache\{0cbbd63f-c6de-4472-b728-ce4bce1ff4b1}"
    )) {
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force; Log "Removed Package Cache: $dir" }
    }
    if (Test-Path "C:\ProgramData\NugetCache") {
        Remove-Item "C:\ProgramData\NugetCache" -Recurse -Force
        Log "Removed NugetCache."
    }

    $dropSql = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$DbName')
BEGIN
    ALTER DATABASE [$DbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$DbName];
END
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$ServiceAccount')
    DROP LOGIN [$ServiceAccount];
GO
"@
    $dropSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Add-Content -Path $LogFile
    Log "Database '$DbName' and login '$ServiceAccount' dropped."
    Log "Secret Server uninstalled."
}

# -- uninstall_iis ---------------------------------------------
if (ShouldRun "uninstall_iis") {
    Step "Uninstall - IIS"
    Import-Module WebAdministration
    $httpsBinding = Get-WebBinding -Name "Default Web Site" -Protocol "https" -ErrorAction SilentlyContinue
    if ($httpsBinding) {
        Remove-WebBinding -Name "Default Web Site" -Protocol "https" -Port 443
        Log "HTTPS binding removed."
    }
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match "CN=ironhold" } | Select-Object -First 1
    if ($cert) {
        Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force
        Log "Certificate removed: $($cert.Thumbprint)"
    }
    Set-Service -Name NetTcpActivator   -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name NetTcpPortSharing -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name NetTcpActivator   -Force -ErrorAction SilentlyContinue
    Stop-Service -Name NetTcpPortSharing -Force -ErrorAction SilentlyContinue
    $features = @(
        "Web-Server","Web-Mgmt-Console","Web-Scripting-Tools",
        "NET-Framework-45-Features","NET-Framework-45-Core","NET-Framework-45-ASPNET",
        "Web-Asp-Net45","Web-Net-Ext45","NET-WCF-Services45",
        "NET-WCF-HTTP-Activation45","NET-WCF-TCP-Activation45","NET-WCF-TCP-PortSharing45",
        "WAS","WAS-Process-Model","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-AppInit",
        "Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Http-Redirect",
        "Web-Static-Content","Web-Http-Logging","Web-Dyn-Compression","Web-Stat-Compression",
        "Web-Filtering","Web-Windows-Auth"
    )
    $installed = $features | Where-Object { (Get-WindowsFeature -Name $_).Installed }
    if ($installed) { Uninstall-WindowsFeature -Name $installed 2>&1 | Add-Content -Path $LogFile; Log "IIS features removed." }
    else            { Log "IIS features already removed." }
    Log "IIS uninstalled."
}

# -- uninstall_sql_db: Drop DB and login only ------------------
if (ShouldRun "uninstall_sql_db") {
    Step "Uninstall - SecretServer DB and login"
    $dropSql = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$DbName')
BEGIN
    ALTER DATABASE [$DbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$DbName];
END
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$ServiceAccount')
    DROP LOGIN [$ServiceAccount];
GO
"@
    $dropSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Add-Content -Path $LogFile
    Log "Database '$DbName' and login '$ServiceAccount' dropped."
}

# -- uninstall_sql: Uninstall SQL Server Express ---------------
if (ShouldRun "uninstall_sql") {
    Step "Uninstall - SQL Server Express"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall sql-server-express -y --no-progress 2>&1 | Add-Content -Path $LogFile
    } else {
        $sqlEntry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
            Where-Object { $_.DisplayName -match "SQL Server.*Express" } | Select-Object -First 1
        if ($sqlEntry -and $sqlEntry.UninstallString) {
            $proc = Start-Process "cmd.exe" -ArgumentList "/c $($sqlEntry.UninstallString) /quiet" -Wait -PassThru
            Log "SQL Server uninstall exit code: $($proc.ExitCode)"
        } else {
            Log "SQL Server Express not found in registry."
        }
    }
    Stop-Service -Name "MSSQL`$SQLEXPRESS" -Force -ErrorAction SilentlyContinue
    Log "SQL Server Express uninstalled."
}

# -- uninstall_choco -------------------------------------------
if (ShouldRun "uninstall_choco") {
    Step "Uninstall - Chocolatey"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        & "$env:ChocolateyInstall\bin\choco.exe" uninstall chocolatey -y --no-progress 2>&1 | Add-Content -Path $LogFile
        Remove-Item "$env:ChocolateyInstall" -Recurse -Force -ErrorAction SilentlyContinue
        [System.Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, "Machine")
        Log "Chocolatey uninstalled."
    } else { Log "Chocolatey not installed." }
}

# -- uninstall_serviceaccount ----------------------------------
if (ShouldRun "uninstall_serviceaccount") {
    Step "Uninstall - service account"
    if (Get-LocalGroupMember -Group "Administrators" -Member $ServiceUser -ErrorAction SilentlyContinue) {
        Remove-LocalGroupMember -Group "Administrators" -Member $ServiceUser
        Log "Removed $ServiceUser from Administrators."
    }
    if (Get-LocalUser -Name $ServiceUser -ErrorAction SilentlyContinue) {
        Remove-LocalUser -Name $ServiceUser
        Log "Local user removed: $ServiceUser"
    } else { Log "Local user not found: $ServiceUser" }
}

# -- uninstall_firewall ----------------------------------------
if (ShouldRun "uninstall_firewall") {
    Step "Uninstall - firewall rules"
    foreach ($name in @("SecretServer-HTTP", "SecretServer-HTTPS")) {
        $existing = netsh advfirewall firewall show rule name=$name 2>&1
        if ($existing -match $name) {
            netsh advfirewall firewall delete rule name=$name | Out-Null
            Log "Firewall rule removed: $name"
        } else { Log "Firewall rule not found: $name" }
    }
}

# ==============================================================
# SUMMARY
# ==============================================================
$hasUninstall = $stepList | Where-Object { $_ -match "^uninstall_" }
$hasInstall   = $stepList | Where-Object { $_ -notmatch "^uninstall_" }

if ($runAll -or $hasInstall) { Step "Installation complete" }
elseif ($hasUninstall)       { Step "Uninstall complete" }

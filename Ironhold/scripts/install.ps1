# =============================================================
#  Secret Server Lab - Installation Script
#  Runs automatically via Vagrant on "vagrant up"
#
#  Idempotent: safe to re-run via "vagrant provision"
#
#  To run only specific steps (comma-separated):
#    $env:SS_STEPS="sql_install"        vagrant provision
#    $env:SS_STEPS="sql_db,ss_extract"  vagrant provision
#    C:\sslab\install.ps1 -Steps "ss_extract,ss_apppool,ss_iisapp"
#
#  Install steps (run automatically on vagrant up):
#    sync_installer      Copy installer files from shared folder to C:\sslab\installer\
#    serviceaccount      Create local service account svc_ss
#    serviceaccount_admin  Add svc_ss to Administrators
#    choco               Install Chocolatey
#    sql_install         Install SQL Server Express
#    sql_auth            Enable mixed-mode authentication
#    sql_db              Create SecretServer DB + login + db_owner
#    sqlcmd              Install sqlcmd command-line tools
#    ssms                [removed - not needed for the lab]
#    tools               Install Firefox and VS Code
#    iis_features        Install IIS / ASP.NET / WCF Windows features
#    iis_cert            Create self-signed cert + HTTPS binding on Default Web Site
#    secretserver        Print manual install instructions (status check)
#    ss_extract          Extract ss_update.zip to C:\inetpub\wwwroot\SecretServer
#    ss_dbconfig         Write database.config (IWA connection, skips setup wizard)
#    ss_apppool          Create and configure SecretServer App Pool (svc_ss identity)
#    ss_iisapp           Register /SecretServer as IIS application under Default Web Site
#    firewall            Open ports 80 and 443
#
#  Uninstall steps (only when explicitly specified):
#    uninstall_secretserver   Remove SS files, IIS app/pool, registry, DB, login
#    uninstall_iis            Remove IIS features, HTTPS binding, cert
#    uninstall_sql_db         Drop SecretServer DB and login only
#    uninstall_sql            Uninstall SQL Server Express
#    uninstall_sqlcmd         Uninstall sqlcmd
#    uninstall_ssms           Uninstall SSMS
#    uninstall_choco          Uninstall Chocolatey
#    uninstall_serviceaccount Remove svc_ss from Administrators and delete user
#    uninstall_firewall       Remove SecretServer firewall rules
# =============================================================
param(
    [string]$Steps = ""   # comma-separated list of steps to run; empty = all
)

$ErrorActionPreference = "Stop"
$LabDir     = "C:\sslab"
$LogFile    = "$LabDir\install.log"
$InstallDir = "C:\inetpub\wwwroot\SecretServer"

# -- Installation mode -----------------------------------------
# "extract"  : extract ss_update.zip + configure IIS manually (default)
#              Requires ss_update.zip in installer/
# "wizard"   : print instructions to run ISVPsetup.exe manually via RDP
$SS_INSTALL_MODE = "extract"

# -- Credentials -----------------------------------------------
$SS_ADMIN           = "admin"
$SS_PASS            = "Passw0rd!"
$SS_EMAIL           = "admin@lab.local"
$SS_DB              = "SecretServer"
$SS_SERVICE_USER    = "svc_ss"
$SS_SERVICE_PASS    = "Passw0rd!"
$SS_SERVICE_ACCOUNT = "$env:COMPUTERNAME\$SS_SERVICE_USER"

# -- Step resolution -------------------------------------------
$runAll   = [string]::IsNullOrWhiteSpace($Steps)
$stepList = $Steps -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
function ShouldRun { param([string]$name)
    if ($name -match "^uninstall_") { return $stepList -contains $name }
    return $runAll -or ($stepList -contains $name)
}

# -- Logging ---------------------------------------------------
function Log  { param($msg) $ts = Get-Date -Format "HH:mm:ss"; $line = "$ts  $msg"; try { $line | Add-Content -Path $LogFile } catch {}; Write-Host $line }
function Step { param($msg) Log ""; Log "==> $msg" }
function Run  { $input | Add-Content -Path $LogFile }
function RunSilent { param([scriptblock]$sb) & $sb 2>&1 | Add-Content -Path $LogFile }

# -- Progress tracking -----------------------------------------
$ssSteps = if ($SS_INSTALL_MODE -eq "extract") {
    @("ss_extract","ss_dbconfig","ss_apppool","ss_iisapp")
} else {
    @("secretserver")
}
$allSteps = @(
    "sync_installer",
    "serviceaccount","serviceaccount_admin","choco",
    "sql_install","sql_auth","sql_db",
    "sqlcmd","ssms",
    "tools",
    "iis_features","iis_cert"
) + $ssSteps + @("firewall")
$plannedSteps  = if ($runAll) { $allSteps } else { $stepList | Where-Object { $_ -notmatch "^uninstall_" } }
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

# -- sync_installer: Copy installer files from shared folder ---
if (ShouldRun "sync_installer") {
    Step "Sync installer files"
    $src = "C:\sslab\installer_src"
    $dst = "$LabDir\installer"
    if (-not (Test-Path $src)) {
        Log "WARN: Shared folder $src not mounted - skipping sync."
        Log "      Ensure the installer/ folder exists on the host and vagrant up has run."
    } else {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Get-ChildItem $src | ForEach-Object {
            $target = "$dst\$($_.Name)"
            if (-not (Test-Path $target)) {
                Copy-Item $_.FullName -Destination $target -Force
                Log "Copied: $($_.Name)"
            } else {
                Log "Already present: $($_.Name)"
            }
        }
        Log "Installer files synced to $dst"
    }
    Done "sync_installer"
}

# -- serviceaccount: Create local user svc_ss ------------------
if (ShouldRun "serviceaccount") {
    Step "Service account - create"
    if (-not (Get-LocalUser -Name $SS_SERVICE_USER -ErrorAction SilentlyContinue)) {
        $secPw = ConvertTo-SecureString $SS_SERVICE_PASS -AsPlainText -Force
        New-LocalUser -Name $SS_SERVICE_USER -Password $secPw -PasswordNeverExpires | Out-Null
        Log "Created local user: $SS_SERVICE_ACCOUNT"
    } else {
        Log "Local user already exists: $SS_SERVICE_ACCOUNT"
    }
    Done "serviceaccount"
}

# -- serviceaccount_admin: Add svc_ss to Administrators --------
if (ShouldRun "serviceaccount_admin") {
    Step "Service account - add to Administrators"
    if (-not (Get-LocalGroupMember -Group "Administrators" -Member $SS_SERVICE_USER -ErrorAction SilentlyContinue)) {
        Add-LocalGroupMember -Group "Administrators" -Member $SS_SERVICE_USER
        Log "Added $SS_SERVICE_USER to Administrators."
    } else {
        Log "$SS_SERVICE_USER is already in Administrators."
    }
    Done "serviceaccount_admin"
}

# -- choco: Install Chocolatey ---------------------------------
if (ShouldRun "choco") {
    Step "Chocolatey"
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        & ([scriptblock]::Create((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))) 2>&1 | Run
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

# -- sql_auth: Enable mixed-mode authentication ----------------
# PATH for sqlcmd bundled with SQL Server Express (available immediately after install)
$env:Path += ";C:\Program Files\Microsoft SQL Server\160\Tools\Binn"
$env:Path += ";C:\Program Files\Microsoft SQL Server\150\Tools\Binn"

if (ShouldRun "sql_auth") {
    Step "SQL Server - mixed-mode auth"
    $currentMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer" -Name "LoginMode" -ErrorAction SilentlyContinue).LoginMode
    if ($currentMode -ne 2) {
        $sqlConfig = @"
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
     N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
GO
"@
        $sqlConfig | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Run
        Restart-Service -Name "MSSQL`$SQLEXPRESS" -Force
        Start-Sleep -Seconds 5
        Log "Mixed-mode auth enabled and SQL Server restarted."
    } else {
        Log "Mixed-mode auth already enabled."
    }
    Done "sql_auth"
}

# PATH for sqlcmd (needed by sql_db and later steps)
$env:Path += ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"

# -- sql_db: Create database, login, db_owner ------------------
if (ShouldRun "sql_db") {
    Step "SQL Server - create DB and login"
    $initSql = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$SS_SERVICE_ACCOUNT')
    CREATE LOGIN [$SS_SERVICE_ACCOUNT] FROM WINDOWS;

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$SS_DB')
    CREATE DATABASE [$SS_DB] COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE [$SS_DB];
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'$SS_SERVICE_ACCOUNT')
    CREATE USER [$SS_SERVICE_ACCOUNT] FOR LOGIN [$SS_SERVICE_ACCOUNT];

IF IS_ROLEMEMBER(N'db_owner', N'$SS_SERVICE_ACCOUNT') <> 1
    ALTER ROLE [db_owner] ADD MEMBER [$SS_SERVICE_ACCOUNT];
GO
"@
    $initSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Run
    Log "Database '$SS_DB' and login '$SS_SERVICE_ACCOUNT' configured."
    Done "sql_db"
}

# -- sqlcmd: Install sqlcmd command-line tools -----------------
if (ShouldRun "sqlcmd") {
    Step "sqlcmd"
    $sqlcmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
    if (-not (Test-Path $sqlcmdPath)) {
        RunSilent { choco install sqlserver-cmdlineutils -y --no-progress 2>&1 }
        Log "sqlcmd installed."
    } else {
        Log "sqlcmd already installed."
    }
    Done "sqlcmd"
}

# ssms step removed - not needed for the lab (Secret Server has its own web UI)

# -- tools: Install Firefox and VS Code ------------------------
if (ShouldRun "tools") {
    Step "Tools - Firefox and VS Code"
    if (-not (Test-Path "$env:ProgramFiles\Mozilla Firefox\firefox.exe")) {
        RunSilent { choco install firefox -y --no-progress 2>&1 }
        Log "Firefox installed."
    } else {
        Log "Firefox already installed."
    }
    if (-not (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")) {
        RunSilent { choco install vscode -y --no-progress 2>&1 }
        Log "VS Code installed."
    } else {
        Log "VS Code already installed."
    }
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        RunSilent { choco install powershell-core -y --no-progress 2>&1 }
        Log "PowerShell 7 installed."
    } else {
        Log "PowerShell 7 already installed."
    }

    # Firefox bookmark: Secret Server
    # Drop a bookmarks.html in the Firefox distribution folder so it is imported
    # on first launch for every new profile (Firefox looks for bookmarks.html there).
    $ffDistDir = "$env:ProgramFiles\Mozilla Firefox\distribution"
    New-Item -ItemType Directory -Force -Path $ffDistDir | Out-Null
    $bookmarksHtml = @"
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Toolbar</H1>
<DL><p>
    <DT><A HREF="http://localhost/SecretServer">Secret Server</A>
</DL><p>
"@
    $bookmarksHtml | Set-Content -Path "$ffDistDir\bookmarks.html" -Encoding UTF8
    Log "Firefox bookmark configured: http://localhost/SecretServer"

    # Taskbar: disable Search and Task View for all users via registry
    $explorerKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $explorerKey)) {
        New-Item -Path $explorerKey -Force | Out-Null
    }
    Set-ItemProperty -Path $explorerKey -Name "HideTaskViewButton" -Value 1 -Type DWord
    Log "Task View button hidden."

    $searchKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $searchKey)) {
        New-Item -Path $searchKey -Force | Out-Null
    }
    Set-ItemProperty -Path $searchKey -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
    Log "Taskbar search box hidden."

    # Taskbar pins: VS Code, IIS Manager, Firefox (unpin Edge)
    # Uses LayoutModification.xml applied via user shell folders policy.
    # Takes effect on next logon.
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
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" `
        -Name "LockedStartLayout" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" `
        -Name "StartLayoutFile" -Value $layoutPath -Type String -ErrorAction SilentlyContinue
    Log "Taskbar pins configured (Firefox, IIS Manager, VS Code). Takes effect on next logon."

    Done "tools"
}

# -- iis_features: Install IIS / ASP.NET / WCF features -------
if (ShouldRun "iis_features") {
    Step "IIS features"
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
    $missing = $features | Where-Object { -not (Get-WindowsFeature -Name $_).Installed }
    if ($missing) {
        RunSilent { Install-WindowsFeature -Name $missing -IncludeManagementTools 2>&1 }
        Log "IIS features installed."
    } else {
        Log "IIS features already installed."
    }
    Set-Service -Name NetTcpActivator   -StartupType Automatic
    Set-Service -Name NetTcpPortSharing -StartupType Automatic
    Start-Service -Name NetTcpActivator
    Start-Service -Name NetTcpPortSharing
    Log "WCF services started."
    Done "iis_features"
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
        # Ensure certificate is assigned
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

# -- secretserver: Status check / manual install notice --------
if (ShouldRun "secretserver") {
    Step "Secret Server"
    if (Test-Path "$InstallDir\web.config") {
        Log "Secret Server is installed."
    } else {
        Log ""
        Log "  *** ACTION REQUIRED ***"
        Log "  Secret Server files are not installed yet."
        Log "  Run:  C:\sslab\install.ps1 -Steps 'ss_extract,ss_apppool,ss_iisapp'"
        Log "  Then navigate to http://localhost/SecretServer to complete setup."
        Log ""
    }
    Done "secretserver"
}

# -- ss_extract: Extract ss_update.zip to wwwroot/SecretServer -
if (ShouldRun "ss_extract") {
    Step "Secret Server - extract files"
    $ssUpdateZip = "$LabDir\installer\ss_update.zip"

    if (Test-Path "$InstallDir\web.config") {
        Log "SS files already present - skipping extraction."
    } elseif (-not (Test-Path $ssUpdateZip)) {
        throw "ss_update.zip not found at $ssUpdateZip. Place it in the Ironhold/installer/ folder and re-run: vagrant provision"
    } else {
        $extractTemp = "$LabDir\ss_extract_temp"
        Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
        Expand-Archive -Path $ssUpdateZip -DestinationPath $extractTemp -Force
        Log "Extracted ss_update.zip to temp folder."

        # Locate web.config (not inside bin/) to find the SS files root
        $webConfigInTemp = Get-ChildItem $extractTemp -Recurse -Filter "web.config" |
            Where-Object { $_.DirectoryName -notmatch "\\bin\\" } | Select-Object -First 1
        if (-not $webConfigInTemp) {
            Log "ERROR: web.config not found inside ss_update.zip."
            Remove-Item $extractTemp -Recurse -Force
        } else {
            $ssFilesRoot = $webConfigInTemp.DirectoryName
            Log "SS files root: $ssFilesRoot"
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

# -- ss_dbconfig: Write database.config (IWA, skips wizard) ---
if (ShouldRun "ss_dbconfig") {
    Step "Secret Server - database.config"
    $dbConfig = "$InstallDir\database.config"
    if (-not (Test-Path $dbConfig)) {
        $dbXml = @"
<?xml version="1.0"?>
<database>
    <Server>localhost\SQLEXPRESS</Server>
    <Database>$SS_DB</Database>
    <UseAuthentication>true</UseAuthentication>
</database>
"@
        $dbXml | Set-Content -Path $dbConfig -Encoding UTF8
        Log "database.config written: localhost\SQLEXPRESS / $SS_DB (IWA)"
    } else {
        Log "database.config already exists - skipping."
    }
    Done "ss_dbconfig"
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
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "managedPipelineMode"            -Value 0       # Integrated
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.userName"          -Value $SS_SERVICE_ACCOUNT
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.password"          -Value $SS_SERVICE_PASS
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.identityType"      -Value 3       # SpecificUser
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.loadUserProfile"   -Value $true
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.idleTimeout"       -Value ([TimeSpan]::Zero)
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "startMode"                      -Value "AlwaysRunning"
    Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "recycling.periodicRestart.time" -Value ([TimeSpan]::Zero)
    Log "App Pool SecretServer configured (identity: $SS_SERVICE_ACCOUNT)"
    Done "ss_apppool"
}

# -- ss_iisapp: Register /SecretServer as IIS application ------
if (ShouldRun "ss_iisapp") {
    Step "Secret Server - IIS application"
    Import-Module WebAdministration

    # Ensure Default Web Site points to wwwroot
    $sitePath = (Get-ItemProperty "IIS:\Sites\Default Web Site").physicalPath
    if ($sitePath -ne "C:\inetpub\wwwroot") {
        Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "physicalPath" -Value "C:\inetpub\wwwroot"
        Log "Corrected Default Web Site physicalPath (was: $sitePath)"
    }

    # Use appcmd for reliable app registration
    $existingApp = & "$env:windir\system32\inetsrv\appcmd.exe" list app "Default Web Site/SecretServer" 2>&1
    if ($existingApp -notmatch "Default Web Site/SecretServer") {
        & "$env:windir\system32\inetsrv\appcmd.exe" add app `
            /site.name:"Default Web Site" `
            /path:"/SecretServer" `
            /physicalPath:$InstallDir `
            /applicationPool:"SecretServer" 2>&1 | Run
        Log "Created IIS application: Default Web Site/SecretServer -> $InstallDir"
    } else {
        & "$env:windir\system32\inetsrv\appcmd.exe" set app "Default Web Site/SecretServer" `
            /physicalPath:$InstallDir `
            /applicationPool:"SecretServer" 2>&1 | Run
        Log "IIS application updated: Default Web Site/SecretServer -> $InstallDir"
    }

    Log ""
    Log "  Navigate to http://localhost/SecretServer to complete setup."
    Log "  The web wizard will configure the database and create the admin user."
    Log ""
    Done "ss_iisapp"
}

# -- firewall: Open ports 80 and 443 ---------------------------
if (ShouldRun "firewall") {
    Step "Firewall"
    foreach ($rule in @(@{ Name = "SecretServer-HTTP"; Port = 80 }, @{ Name = "SecretServer-HTTPS"; Port = 443 })) {
        $existing = netsh advfirewall firewall show rule name=$rule.Name 2>&1
        if ($existing -notmatch $rule.Name) {
            netsh advfirewall firewall add rule `
                name=$rule.Name protocol=TCP dir=in localport=$rule.Port action=allow | Out-Null
            Log "Firewall rule added: $($rule.Name) (port $($rule.Port))"
        } else {
            Log "Firewall rule already exists: $($rule.Name)"
        }
    }
    Done "firewall"
}

# ==============================================================
# UNINSTALL STEPS
# ==============================================================

# -- uninstall_secretserver ------------------------------------
if (ShouldRun "uninstall_secretserver") {
    Step "Uninstall - Secret Server"
    Import-Module WebAdministration

    # MSI uninstall via WiX bundle keys
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

    # Thycotic.Installers.Dependencies
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

    # Registry cleanup
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

    # IIS application and App Pool
    if (Get-WebApplication -Site "Default Web Site" -Name "SecretServer" -ErrorAction SilentlyContinue) {
        Remove-WebApplication -Site "Default Web Site" -Name "SecretServer"
        Log "IIS application /SecretServer removed."
    }
    if (Test-Path "IIS:\AppPools\SecretServer") {
        Stop-WebAppPool -Name "SecretServer" -ErrorAction SilentlyContinue
        Remove-WebAppPool -Name "SecretServer"
        Log "App Pool SecretServer removed."
    }

    # Restore Default Web Site app pool if it was changed
    $sitePool = (Get-ItemProperty "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue).applicationPool
    if ($sitePool -eq "SecretServer") {
        Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "applicationPool" -Value "DefaultAppPool"
        Log "Default Web Site app pool restored to DefaultAppPool."
    }

    # Restore Default Web Site physical path if it was changed
    $sitePath = (Get-ItemProperty "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue).physicalPath
    if ($sitePath -ne "C:\inetpub\wwwroot") {
        Set-ItemProperty "IIS:\Sites\Default Web Site" -Name "physicalPath" -Value "C:\inetpub\wwwroot"
        Log "Default Web Site physicalPath restored to C:\inetpub\wwwroot."
    }

    # Install folder
    if (Test-Path "C:\inetpub\wwwroot\SecretServer") {
        Remove-Item "C:\inetpub\wwwroot\SecretServer" -Recurse -Force
        Log "Install folder removed."
    }

    # WiX Package Cache
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

    # Drop DB and login
    $dropSql = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$SS_DB')
BEGIN
    ALTER DATABASE [$SS_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$SS_DB];
END
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$SS_SERVICE_ACCOUNT')
    DROP LOGIN [$SS_SERVICE_ACCOUNT];
GO
"@
    $dropSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Run
    Log "Database '$SS_DB' and login '$SS_SERVICE_ACCOUNT' dropped."
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
    if ($installed) { Uninstall-WindowsFeature -Name $installed 2>&1 | Run; Log "IIS features removed." }
    else            { Log "IIS features already removed." }
    Log "IIS uninstalled."
}

# -- uninstall_sql_db: Drop DB and login only ------------------
if (ShouldRun "uninstall_sql_db") {
    Step "Uninstall - SecretServer DB and login"
    $dropSql = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$SS_DB')
BEGIN
    ALTER DATABASE [$SS_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$SS_DB];
END
IF EXISTS (SELECT name FROM sys.server_principals WHERE name = N'$SS_SERVICE_ACCOUNT')
    DROP LOGIN [$SS_SERVICE_ACCOUNT];
GO
"@
    $dropSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Run
    Log "Database '$SS_DB' and login '$SS_SERVICE_ACCOUNT' dropped."
}

# -- uninstall_sql: Uninstall SQL Server Express ---------------
if (ShouldRun "uninstall_sql") {
    Step "Uninstall - SQL Server Express"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall sql-server-express -y --no-progress 2>&1 | Run
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

# -- uninstall_sqlcmd ------------------------------------------
if (ShouldRun "uninstall_sqlcmd") {
    Step "Uninstall - sqlcmd"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall sqlserver-cmdlineutils -y --no-progress 2>&1 | Run
        Log "sqlcmd uninstalled."
    } else {
        Log "Chocolatey not available."
    }
}

# -- uninstall_ssms --------------------------------------------
if (ShouldRun "uninstall_ssms") {
    Step "Uninstall - SSMS"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco uninstall sql-server-management-studio -y --no-progress 2>&1 | Run
        Log "SSMS uninstalled."
    } else {
        Log "Chocolatey not available."
    }
}

# -- uninstall_choco -------------------------------------------
if (ShouldRun "uninstall_choco") {
    Step "Uninstall - Chocolatey"
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        & "$env:ChocolateyInstall\bin\choco.exe" uninstall chocolatey -y --no-progress 2>&1 | Run
        Remove-Item "$env:ChocolateyInstall" -Recurse -Force -ErrorAction SilentlyContinue
        [System.Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, "Machine")
        Log "Chocolatey uninstalled."
    } else {
        Log "Chocolatey not installed."
    }
}

# -- uninstall_serviceaccount ----------------------------------
if (ShouldRun "uninstall_serviceaccount") {
    Step "Uninstall - service account"
    if (Get-LocalGroupMember -Group "Administrators" -Member $SS_SERVICE_USER -ErrorAction SilentlyContinue) {
        Remove-LocalGroupMember -Group "Administrators" -Member $SS_SERVICE_USER
        Log "Removed $SS_SERVICE_USER from Administrators."
    }
    if (Get-LocalUser -Name $SS_SERVICE_USER -ErrorAction SilentlyContinue) {
        Remove-LocalUser -Name $SS_SERVICE_USER
        Log "Local user removed: $SS_SERVICE_USER"
    } else {
        Log "Local user not found: $SS_SERVICE_USER"
    }
}

# -- uninstall_firewall ----------------------------------------
if (ShouldRun "uninstall_firewall") {
    Step "Uninstall - firewall rules"
    foreach ($name in @("SecretServer-HTTP", "SecretServer-HTTPS")) {
        $existing = netsh advfirewall firewall show rule name=$name 2>&1
        if ($existing -match $name) {
            netsh advfirewall firewall delete rule name=$name | Out-Null
            Log "Firewall rule removed: $name"
        } else {
            Log "Firewall rule not found: $name"
        }
    }
}

# ==============================================================
# SUMMARY
# ==============================================================
$hasUninstall = $stepList | Where-Object { $_ -match "^uninstall_" }
$hasInstall   = $stepList | Where-Object { $_ -notmatch "^uninstall_" }

if ($runAll -or $hasInstall) { Step "Installation complete" }
elseif ($hasUninstall)       { Step "Uninstall complete" }

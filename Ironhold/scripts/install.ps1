# =============================================================
#  Secret Server Lab - Installation Script
#  Runs automatically via Vagrant on "vagrant up"
#  No need to run this manually
#
#  Idempotent: safe to re-run via "vagrant provision"
#
#  To run only specific steps (comma-separated, host side):
#    $env:SS_STEPS="sql"          vagrant provision   # only SQL
#    $env:SS_STEPS="iis,install"  vagrant provision   # prerequisites + official CLI installer
#
#  Valid step names:
#    choco      Install Chocolatey
#    sql        Install + configure SQL Server Express
#    sqltools   Install sqlcmd tools and SQL Server Management Studio
#    iis        Enable IIS / ASP.NET features
#    install    Install Secret Server with the official EXE command line
#    iisconfig  Apply recommended settings to the installer-created IIS app pool
#    dbconfig   Reserved; database configuration is owned by the official installer
#    firewall   Open ports 80 and 443 in firewall
# =============================================================
param(
    [string]$Steps = ""   # comma-separated list of steps to run; empty = all
)

$ErrorActionPreference = "Stop"
$LabDir  = "C:\sslab"
$LogFile = "$LabDir\install.log"

# Resolve which steps to run
$runAll   = [string]::IsNullOrWhiteSpace($Steps)
$stepList = $Steps -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
function ShouldRun { param([string]$name) return $runAll -or ($stepList -contains $name) }

# Read a variable from the env file
function Get-EnvVar {
    param([string]$Key, [string]$Default = "")
    $line = Get-Content "$LabDir\lab.env" | Where-Object { $_ -match "^\s*$Key\s*=" } | Select-Object -First 1
    if ($line) { return ($line -split "=", 2)[1].Trim() }
    return $Default
}

function Log  { param($msg) $ts = Get-Date -Format "HH:mm:ss"; "$ts  $msg" | Tee-Object -FilePath $LogFile -Append }
function Step { param($msg) Log ""; Log "==> $msg" }

Step "Starting Secret Server lab installation"
if (-not $runAll) { Log "Running steps: $($stepList -join ', ')" }

$SA_PASS         = Get-EnvVar "SA_PASSWORD"     -Default "Passw0rd!"
$SS_ADMIN        = Get-EnvVar "SS_ADMIN_USER"   -Default "admin"
$SS_PASS         = Get-EnvVar "SS_ADMIN_PASS"   -Default "Passw0rd!"
$SS_EMAIL        = Get-EnvVar "SS_ADMIN_EMAIL"  -Default "admin@lab.local"
$SS_DB           = Get-EnvVar "SS_DB_NAME"      -Default "SecretServer"
$SS_SERVICE_USER = Get-EnvVar "SS_SERVICE_USER" -Default "svc_ss"
$SS_SERVICE_PASS = Get-EnvVar "SS_SERVICE_PASS" -Default "Passw0rd!"
$SS_SERVICE_ACCOUNT = "$env:COMPUTERNAME\$SS_SERVICE_USER"

if (-not (Get-LocalUser -Name $SS_SERVICE_USER -ErrorAction SilentlyContinue)) {
    $secureServicePassword = ConvertTo-SecureString $SS_SERVICE_PASS -AsPlainText -Force
    New-LocalUser -Name $SS_SERVICE_USER `
                  -Password $secureServicePassword `
                  -PasswordNeverExpires | Out-Null
    Log "Service account created: $SS_SERVICE_ACCOUNT"
}

# -- 1. Install Chocolatey (package manager) -------------------
if (ShouldRun "choco") {
    Step "Installing Chocolatey"
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Log "Chocolatey installed."
    } else {
        Log "Chocolatey already installed."
    }
}
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# -- 2. Install SQL Server Express -----------------------------
if (ShouldRun "sql") {
    Step "Installing SQL Server Express"
    if (-not (Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue)) {
        choco install sql-server-express -y --no-progress 2>&1 | Tee-Object -FilePath $LogFile -Append
        Log "SQL Server installed."
    } else {
        Log "SQL Server already installed."
    }
}

# -- 3. Install SQL Server management tools --------------------
if (ShouldRun "sqltools") {
    Step "Installing SQL Server management tools"
    $sqlcmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"
    if (-not (Test-Path $sqlcmdPath)) {
        choco install sqlserver-cmdlineutils -y --no-progress 2>&1 | Tee-Object -FilePath $LogFile -Append
        Log "SQL cmd tools installed."
    } else {
        Log "SQL cmd tools already installed."
    }

    choco install sql-server-management-studio -y --no-progress 2>&1 | Tee-Object -FilePath $LogFile -Append
    Log "SQL Server Management Studio installed."
}
$env:Path += ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn"

# -- 4. Configure SQL Server (mixed auth, create database) -----
if (ShouldRun "sql") {
    Step "Configuring SQL Server"

    # Check current auth mode (2 = mixed); only change and restart if needed
    $currentMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer" -Name "LoginMode" -ErrorAction SilentlyContinue).LoginMode
    if ($currentMode -ne 2) {
        $sqlConfig = @"
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
     N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;
GO
"@
        $sqlConfig | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Tee-Object -FilePath $LogFile -Append
        Restart-Service -Name "MSSQL`$SQLEXPRESS" -Force
        Start-Sleep -Seconds 5
        Log "Mixed-mode auth enabled and SQL Server restarted."
    } else {
        Log "Mixed-mode auth already enabled."
    }

    # Create database and grant the IIS service account access (idempotent)
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
    $initSql | sqlcmd -S "localhost\SQLEXPRESS" -E 2>&1 | Tee-Object -FilePath $LogFile -Append
    Log "SQL Server configured."
}

# -- 5. Enable IIS and ASP.NET ---------------------------------
if (ShouldRun "iis") {
    Step "Enabling IIS and ASP.NET 4.8"
    $features = @(
        "Web-Server",
        "Web-Mgmt-Console",
        "Web-Scripting-Tools",
        "NET-Framework-45-Features",
        "NET-Framework-45-Core",
        "NET-Framework-45-ASPNET",
        "Web-Asp-Net45",
        "Web-Net-Ext45",
        "NET-WCF-Services45",
        "NET-WCF-HTTP-Activation45",
        "NET-WCF-TCP-Activation45",
        "NET-WCF-TCP-PortSharing45",
        "WAS",
        "WAS-Process-Model",
        "Web-ISAPI-Ext",
        "Web-ISAPI-Filter",
        "Web-AppInit",
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Http-Redirect",
        "Web-Static-Content",
        "Web-Http-Logging",
        "Web-Dyn-Compression",
        "Web-Stat-Compression",
        "Web-Filtering",
        "Web-Windows-Auth"
    )
    $missing = $features | Where-Object { -not (Get-WindowsFeature -Name $_).Installed }
    if ($missing) {
        Install-WindowsFeature -Name $missing -IncludeManagementTools 2>&1 | Tee-Object -FilePath $LogFile -Append
        Log "IIS features installed."
    } else {
        Log "IIS already enabled."
    }

    Set-Service -Name NetTcpActivator -StartupType Automatic
    Set-Service -Name NetTcpPortSharing -StartupType Automatic
    Start-Service -Name NetTcpActivator
    Start-Service -Name NetTcpPortSharing
}

# -- 6 + 7. Install Secret Server through the official CLI -----
if (ShouldRun "install") {
    Step "Locating Secret Server EXE installer"

    $installerDir = "$LabDir\installer"
    $installerExe = Get-ChildItem "$installerDir\*.exe" -ErrorAction SilentlyContinue |
        Sort-Object { if ($_.Name -match "^(Thycotic|Delinea)Setup\.exe$") { 0 } else { 1 } }, Name |
        Select-Object -First 1

    if (-not $installerExe) {
        Log "ERROR: Secret Server EXE installer not found in $installerDir"
        Log "Copy ThycoticSetup.exe or DelineaSetup.exe there and run vagrant provision."
        exit 1
    }

    Log "EXE installer found: $($installerExe.FullName)"
    $installDir = "C:\inetpub\wwwroot\SecretServer"

    if (Test-Path "$installDir\web.config") {
        Log "Secret Server already installed - skipping official installer."
    } else {
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        & icacls.exe $installDir /grant "${SS_SERVICE_ACCOUNT}:(OI)(CI)M" /T /C | Tee-Object -FilePath $LogFile -Append

        Step "Installing official prerequisites and HTTPS binding"
        $prereqLog = "$LabDir\install-prerequisites.log"
        $prereqArgs = @(
            "-q",
            "-s",
            "InstallPreReqs=1",
            "PRE_REQS_TO_INSTALL=INSTALL_IIS,INSTALL_IIS_COMPS,INSTALL_NET_WCF,INSTALL_HTTPS_BINDING,INSTALL_NetFx48",
            "/l",
            $prereqLog
        )
        $proc = Start-Process -FilePath $installerExe.FullName -ArgumentList $prereqArgs -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -notin 0, 3010) {
            Log "ERROR: Prerequisite installer exited with code $($proc.ExitCode). Check $prereqLog"
            exit $proc.ExitCode
        }

        Step "Installing Secret Server with the official command line"
        $ssInstallerLog = "$LabDir\ss-install.log"
        $ssArgs = @(
            "-q",
            "-s",
            "InstallSecretServer=1",
            "InstallPrivilegeManager=0",
            "CreateWebSite=1",
            "SecretServerSiteName=Default Web Site",
            "SecretServerSitePort=80",
            "SecretServerSiteHttpsPort=443",
            "SecretServerApplicationName=SecretServer",
            "SecretServerDestinationFolderPath=$installDir",
            "SecretServerAppUserName=$SS_SERVICE_ACCOUNT",
            "SecretServerAppPassword=$SS_SERVICE_PASS",
            "DatabaseServer=localhost\SQLEXPRESS",
            "DatabaseName=$SS_DB",
            "DatabaseIsUsingWindowsAuthentication=1",
            "SecretServerUserName=$SS_ADMIN",
            "SecretServerUserPassword=$SS_PASS",
            "SecretServerUserDisplayName=$SS_ADMIN",
            "SecretServerUserEmail=$SS_EMAIL",
            "/l",
            $ssInstallerLog,
            "/nodetect"
        )
        $proc = Start-Process -FilePath $installerExe.FullName -ArgumentList $ssArgs -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -ne 0) {
            Log "ERROR: Installer exited with code $($proc.ExitCode). Check $ssInstallerLog"
            exit $proc.ExitCode
        }
        Log "Secret Server installed successfully. Log: $ssInstallerLog"
    }
}

$installDir = "C:\inetpub\wwwroot\SecretServer"

# -- 8. Apply recommended settings to installer-created IIS ----
if (ShouldRun "iisconfig") {
    Step "Applying recommended IIS application pool settings"
    Import-Module WebAdministration

    if (Test-Path "IIS:\AppPools\SecretServer") {
        Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.loadUserProfile" -Value $true
        Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "processModel.idleTimeout" -Value ([TimeSpan]::Zero)
        Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "startMode" -Value "AlwaysRunning"
        Set-ItemProperty "IIS:\AppPools\SecretServer" -Name "recycling.periodicRestart.time" -Value ([TimeSpan]::Zero)
        & icacls.exe $installDir /grant "${SS_SERVICE_ACCOUNT}:(OI)(CI)M" /T /C | Tee-Object -FilePath $LogFile -Append
        Restart-WebAppPool -Name "SecretServer"
        Log "Installer-created IIS configuration updated."
    } else {
        Log "WARN: SecretServer application pool not found; run the install step first."
    }
}

# -- 9. Database configuration is performed by official EXE ----
if (ShouldRun "dbconfig") {
    Step "Database configuration"
    Log "Database settings are managed by the official EXE installer; no manual database.config changes applied."
}

# -- 10. Open firewall for host access -------------------------
if (ShouldRun "firewall") {
    Step "Configuring firewall"
    foreach ($binding in @(@{ Name = "SecretServer-HTTP"; Port = 80 }, @{ Name = "SecretServer-HTTPS"; Port = 443 })) {
        $fwRule = netsh advfirewall firewall show rule name=$binding.Name 2>&1
        if ($fwRule -notmatch $binding.Name) {
            netsh advfirewall firewall add rule `
                name=$binding.Name `
                protocol=TCP `
                dir=in `
                localport=$binding.Port `
                action=allow | Out-Null
            Log "Firewall rule added: $($binding.Name)"
        }
    }
}

Step "Installation complete"

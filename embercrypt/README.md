# Embercrypt

The Embercrypt was not built as a strongroom. It was the sealing chamber of the guilds - the place where credentials, signing keys, and access codes were deposited when a master retired or a guild dissolved. Nothing was destroyed. Nothing was returned. It went in and stayed.

When the guilds collapsed, the Embercrypt was left full of orphaned credentials. Nobody decommissioned it. Nobody reconnected it either. It has been sealed since.

Reconnecting Embercrypt to the city is not a technical problem. It is a problem of trust. The guilds that still operate know what the Embercrypt is. Depositing credentials there means accepting that when they are gone, those credentials stay.

> **This is a fictional lab environment. Do not use in production.**

Runs on Windows Server 2025.

## Requirements

- [Vagrant](https://www.vagrantup.com/)
- [VMware Workstation](https://www.vmware.com/products/workstation-pro.html) or [Fusion](https://www.vmware.com/products/fusion.html)
- [vagrant-vmware-desktop](https://developer.hashicorp.com/vagrant/docs/providers/vmware/installation) plugin
- Installer files in `installer/` (see below)

### Installer files

Place the following files in the `installer/` folder before running `vagrant up`:

| File | How to obtain |
|------|---------------|
| `ISVPsetup.exe` | Obtain the installer package from your authorized software source |
| `ss_update.zip` | Extract from `Version_12_0_000022.zip` inside the downloaded package |

## Setup

### Step 1 - Start the VM

```powershell
vagrant up
```

Provisions SQL Server Express, IIS, ASP.NET, the service account, and the application files (~20 min).

### Step 2 - Complete the database setup wizard

Connect to the VM via RDP (`localhost:53389`, credentials: `vagrant` / `vagrant`), open Firefox and navigate to:

```
http://localhost/SecretServer/Setup/Database?FreshInstall=true
```

Fill in the wizard fields:

| Field | Value |
|-------|-------|
| Database Server | `localhost\SQLEXPRESS` |
| Database Name | `SecretServer` |
| Authentication | Windows Authentication |

### Step 3 - Create the admin account

After the DB wizard completes, the setup wizard will prompt for the admin account:

| Field | Value |
|-------|-------|
| Username | `admin` |
| Display name | `Admin` |
| Email | `admin@lab.local` |
| Password | `Ir0nhold#Lab!` |

## Access

| URL | Description |
|-----|-------------|
| `http://localhost/SecretServer` | From inside the VM |
| `http://localhost:8010/SecretServer` | From the host (port-forwarded) |
| `https://localhost:4430/SecretServer` | HTTPS from the host (self-signed cert) |

## Credentials

| What | Value |
|------|-------|
| Application admin | `admin` / `Ir0nhold#Lab!` |
| RDP / VM | `vagrant` / `vagrant` |
| Service account | `Embercrypt\svc_ss` / `Ir0nhold#Lab!` |
| Database | `SecretServer` on `localhost\SQLEXPRESS` (Windows Auth) |

## Re-provisioning

```powershell
# Re-run all steps
vagrant provision

# Re-run only specific steps (from inside the VM via RDP)
C:\sslab\install.ps1 -Steps "ss_install,ss_apppool,ss_iisapp"

# Use zip extraction instead of installer
C:\sslab\install.ps1 -InstallMode extract -Steps "ss_extract,ss_apppool,ss_iisapp"
```

## Uninstall the application

From RDP on the VM:

```powershell
C:\sslab\install.ps1 -Steps "uninstall_secretserver"
```

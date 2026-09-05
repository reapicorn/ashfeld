# Ironhold - The Vault

Before the foundries closed, Ironhold was the most secure facility in the district. The guilds kept what they could not afford to lose there — signing keys, access codes, the credentials for systems that had no other documentation. The guilds are gone. The building is still standing. The vault was never decommissioned.

Today Ironhold is the privileged access vault for Ashfeld. If something has a password that matters, it goes through here.

> **WARNING: This is a fictional lab environment. Do not use in production.**

## Requirements

- [Vagrant](https://www.vagrantup.com/)
- [VMware Workstation](https://www.vmware.com/products/workstation-pro.html) or [Fusion](https://www.vmware.com/products/fusion.html)
- [vagrant-vmware-desktop](https://developer.hashicorp.com/vagrant/docs/providers/vmware/installation) plugin
- Installer files in `installer/` (see below)

### Installer files

Place the following files in the `installer/` folder before running `vagrant up`:

| File | How to obtain |
|------|---------------|
| `ISVPsetup.exe` | Download from the Delinea portal |
| `ss_update.zip` | Extract from `Version_12_0_000022.zip` (inside the downloaded package) |

## Setup

### Step 1 - Start the VM

```powershell
vagrant up
```

Provisions SQL Server Express, IIS, ASP.NET, service account, and Secret Server files (~20 min).

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
| Password | `Ir0nhold#Lab!` |

## Access

| URL | Description |
|-----|-------------|
| `http://localhost/SecretServer` | From inside the VM |
| `http://localhost:8080/SecretServer` | From the host (port-forwarded) |
| `https://localhost:8443/SecretServer` | HTTPS from the host (self-signed cert) |

## Credentials

| What | Value |
|------|-------|
| Secret Server admin | `admin` / `Ir0nhold#Lab!` |
| RDP / VM | `vagrant` / `vagrant` |
| Service account | `IRONHOLD\svc_ss` / `Ir0nhold#Lab!` |
| Database | `SecretServer` on `localhost\SQLEXPRESS` (Windows Auth) |

## Re-provisioning

```powershell
# Re-run all steps
vagrant provision

# Re-run only specific steps (from inside the VM via RDP)
C:\sslab\install.ps1 -Steps "ss_extract,ss_apppool,ss_iisapp"
```

## Uninstall Secret Server

From RDP on the VM:

```powershell
C:\sslab\install.ps1 -Steps "uninstall_secretserver"
```

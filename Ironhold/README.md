# Ironhold

Before the foundries closed, Ironhold was the district's most secure facility — a fortified records vault where the guilds kept what they could not afford to lose. Master keys. Payroll ciphers. The names behind the accounts. Nothing left that building without a signature and a witness.

The guilds are gone. The building is still standing. The vault where privileged credentials live. Every service account, every admin password, every infrastructure secret in Ashfeld is checked in here. If something has a password that matters, it goes through Ironhold.

---

## Vagrant

### Before starting

The installer is not included. Obtain it separately and place it in `installer/` (any filename, `.exe` or `.zip`).

### Start

```bash
vagrant up
```

Vagrant downloads a Windows Server 2025 VM (~7 GB, first time only), installs SQL Server Express, and provisions the vault. First run: ~15 minutes. Subsequent starts: ~2 minutes.

### Access

| | |
|---|---|
| URL | `http://10.10.10.10/SecretServer` |
| Username | `admin` |
| Password | `Passw0rd!` |
| RDP | `10.10.10.10:3389` — `vagrant` / `vagrant` |

### Day-to-day

```bash
# Stop
vagrant halt

# Start
vagrant up

# RDP into the VM
vagrant rdp

# Re-run provisioning (if it failed mid-way)
vagrant provision

# Destroy and start fresh
vagrant destroy -f && vagrant up
```

### Machine requirements

| Resource | Value |
|---|---|
| CPU | 2 vCPU |
| RAM | 4 GB |
| Disk | 25 GB |

---

## Secret structure

Secrets are organized in folders by category:

```
Ashfeld/
├── Infrastructure/      ← servers, network devices
├── Databases/           ← service accounts for DB access
├── Applications/        ← app-level credentials
└── Privileged Accounts/ ← admin and break-glass accounts
```

---

## Exercises

| # | Topic | Time |
|---|---|---|
| [01 — First steps](docs/01-first-steps.md) | UI, initial wizard, first user | 20 min |
| [02 — Basic secrets](docs/02-basic-secrets.md) | Folders, secret types, audit trail | 30 min |
| [03 — Groups & users](docs/03-groups-and-users.md) | Roles, groups, folder permissions | 30 min |
| [04 — Access policies](docs/04-access-policies.md) | Checkout, approval workflow, auto-rotation | 45 min |
| [05 — Audit & reports](docs/05-audit-and-reports.md) | Logs, reports, alerts, incident simulation | 30 min |

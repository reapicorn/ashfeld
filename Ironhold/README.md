# Ironhold

Before the foundries closed, Ironhold was the district's most secure facility — a fortified records vault where the guilds kept what they could not afford to lose. Master keys. Payroll ciphers. The names behind the accounts. Nothing left that building without a signature and a witness.

The guilds are gone. The building is still standing. The vault where privileged credentials live. Every service account, every admin password, every infrastructure secret in Ashfeld is checked in here. If something has a password that matters, it goes through Ironhold.

---

## Access

| Service | URL |
|---|---|
| Secret Server | `http://localhost:8080/SecretServer` |

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `Passw0rd!` |

VM credentials (RDP): `vagrant` / `vagrant`

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

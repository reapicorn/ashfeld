# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab puts you in the city and gives you the keys. The backends are real, the protocols are live, and the data is already there waiting. You are not reading about identity provisioning — you are doing it, against systems that behave the way systems behave in the real world: inconsistently, on their own terms, without a common standard in sight.

```
.
└── darkhorn/        # the district — six companies, six ways of keeping the same records
```

---

## Projects

### darkhorn

Six companies settled in the Darkhorn district after the foundries closed. None of them inherited the same systems. None of them agreed to standardize. They each handle the same three questions — who works here, what do they have access to, are they still active — and they each answer in a different language.

→ See [`darkhorn/README.md`](darkhorn/README.md) — the six companies, their doors, and what moves across the wire.

---

## Standing it up

### The machine

> **⚠️ DRAFT — needs validation against real lab usage before publishing.**

The full stack runs on a single machine. Ashfeld never had much to work with — neither does this lab.

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Disk | 15 GB | 20 GB |

### Choose your ground

Windows Server 2025 VM running IBM Verify Privilege Vault.

### Before starting

The installer is not included. Get it from the IBM source and place it in `Ironhold/installer/` (any filename, `.exe` or `.zip`).

### Start

```powershell
cd Ironhold
vagrant up --provider=vmware_desktop
```

Vagrant downloads a Windows Server 2025 VM (~7 GB, first time only), installs SQL Server Express, and installs and configures IBM Verify Privilege Vault. First run: ~15 minutes. Subsequent starts: ~2 minutes.

### Day-to-day

```powershell
# Stop
vagrant halt

# Start
vagrant up --provider=vmware_desktop

# RDP into the VM
vagrant rdp
# Credentials: vagrant / vagrant

# Re-run provisioning (if it failed mid-way)
vagrant provision

# Destroy and start fresh
vagrant destroy -f && vagrant up --provider=vmware_desktop
```

### Machine requirements

| Resource | Value |
|---|---|
| CPU | 2 vCPU |
| RAM | 4 GB |
| Disk | 25 GB |

Two options. One is leaner and expects you to know what you're doing. The other is more forgiving. Pick the one that fits.

---

## Thorngate

The script below detects the distribution and installs everything needed. Run it once and don't think about it again.

```bash
cd Thorngate
vagrant up --provider=vmware_desktop
```

If it installed correctly:

```bash
# Stop
vagrant halt

# Start
vagrant up --provider=vmware_desktop

## Clone the archive

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

---

## Starting the city

```bash
cd ~/ashfeld/darkhorn && docker compose up --build -d
```

---

## The gates

```bash
sudo ufw allow 22/tcp       # SSH — always first
sudo ufw allow 3000/tcp     # REST
sudo ufw allow 5432/tcp     # JDBC / PostgreSQL
sudo ufw allow 389/tcp      # LDAP
sudo ufw allow 2222/tcp     # SFTP
sudo ufw allow 3002/tcp     # SOAP
sudo ufw allow 5672/tcp     # AMQP
sudo ufw allow 15672/tcp    # RabbitMQ Management UI
sudo ufw enable
```

---

## Working in the city

### The logs

```bash
# All services
docker compose logs -f

# Single service
docker compose logs -f <service_name>
```

**darkhorn** service names: `darkhorn-rest` `darkhorn-postgres` `darkhorn-ldap` `darkhorn-sftp` `darkhorn-soap` `darkhorn-mq` `darkhorn-rabbitmq`

### Status

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

---

## Shutting it down

> **⚠️** This removes everything — containers, volumes, and the files themselves. Ashfeld will be gone. There is no undo.

```bash
cd ~/ashfeld/darkhorn && docker compose down -v
cd ~ && sudo rm -rf ~/ashfeld
```

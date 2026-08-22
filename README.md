# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab puts you in the city and gives you the keys. The backends are real, the protocols are live, and the data is already there waiting. You are not reading about identity provisioning — you are doing it, against systems that behave the way systems behave in the real world: inconsistently, on their own terms, without a common standard in sight.

```
.
├── hollowcrown/     # the Bureau — employee records, the only list anyone agrees to use
└── darkhorn/        # the district — six companies, six ways of keeping the same records
```

Each project has its own `docker-compose.yml` and runs independently.

---

## Projects

### hollowcrown

The Hollowcrown Bureau is what remains of the council that once ran this city. It still keeps the roster — who was hired, who transferred, who never came back. The data is old in places and contested in others, but it is the only list anyone agrees to use. The web UI is how the clerks update it. The API is how the rest of the city reads it.

→ See [`hollowcrown/README.md`](hollowcrown/README.md) — the Bureau's records and how to read them.

### darkhorn

Six companies settled in the Darkhorn district after the foundries closed. None of them inherited the same systems. None of them agreed to standardize. They each handle the same thirteen questions — who works here, what do they have access to, are they still active — and they each answer in a different language.

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

| OS | Notes |
|---|---|
| **Debian 12 (Bookworm)** | Recommended. Minimal image (~200 MB), stable, supported until 2028. Official Docker packages available. Slightly higher technical challenge than Ubuntu — good practice for production-like environments. |
| Ubuntu Server 22.04 LTS | Good alternative. More overhead (~400 MB), but more documentation available online and a friendlier experience for beginners. |

Two options. One is leaner and expects you to know what you're doing. The other is more forgiving. Pick the one that fits.

---

## Installing Docker

The script below detects the distribution and installs everything needed. Run it once and don't think about it again.

```bash
set -e

# Detect distro (debian or ubuntu)
DISTRO=$(. /etc/os-release && echo "$ID")
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker
```

If it installed correctly:

```bash
docker version
docker compose version
```

---

## Clone the archive

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

---

## Starting the city

```bash
cd ~/ashfeld/hollowcrown && docker compose up --build -d
cd ~/ashfeld/darkhorn && docker compose up --build -d
cd ~
```

Both can run on the same machine at the same time. The city doesn't need much space — it never did.

---

## The gates

```bash
sudo ufw allow 22/tcp       # SSH — always first
sudo ufw allow 8080/tcp     # hollowcrown web UI
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

**hollowcrown** service names: `hollowcrown-api` `hollowcrown-web` `hollowcrown-db`

**darkhorn** service names: `darkhorn-rest` `darkhorn-postgres` `darkhorn-ldap` `darkhorn-sftp` `darkhorn-soap` `darkhorn-mq` `darkhorn-rabbitmq`

### Status

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

---

## Shutting it down

> **⚠️** This removes everything — containers, volumes, and the files themselves. Ashfeld will be gone. There is no undo.

```bash
cd ~/ashfeld/hollowcrown && docker compose down -v
cd ~/ashfeld/darkhorn && docker compose down -v
cd ~ && sudo rm -rf ~/ashfeld
```

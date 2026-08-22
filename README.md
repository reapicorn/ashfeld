# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab reproduces that environment. It is a self-contained infrastructure for building and testing identity provisioning integrations against real backends.

```
.
├── hollowcrown/     # HR source system — employee records, web UI
└── darkhorn/        # Target systems — REST, JDBC, LDAP, SFTP, SOAP, MQ
```

Each project has its own `docker-compose.yml` and runs independently.

---

## Projects

### hollowcrown

A fictional HR system that acts as the upstream source of employee data. Includes a web UI for managing employees and a REST API that the adapter can poll.

→ See [`hollowcrown/README.md`](hollowcrown/README.md) for the API reference and employee model.

### darkhorn

Six backend services (REST, SOAP, MQ, JDBC, SFTP, LDAP), each exposing the same 13 identity operations over a different protocol.

→ See [`darkhorn/README.md`](darkhorn/README.md) for credentials, endpoint reference and data contract examples.

---

## Infrastructure

### VM requirements

> **⚠️ DRAFT — needs validation against real lab usage before publishing.**

The full stack (both projects) runs comfortably on a single VM.

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Disk | 15 GB | 20 GB |

### Operating system

| OS | Notes |
|---|---|
| **Debian 12 (Bookworm)** | Recommended. Minimal image (~200 MB), stable, supported until 2028. Official Docker packages available. Slightly higher technical challenge than Ubuntu — good practice for production-like environments. |
| Ubuntu Server 22.04 LTS | Good alternative. More overhead (~400 MB), but more documentation available online and a friendlier experience for beginners. |

---

## Installing Docker

The script below detects the current distribution automatically and works on both Debian and Ubuntu.

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

Verify:

```bash
docker version
docker compose version
```

---

## Getting the files onto the server

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

---

## Starting each project

```bash
cd ~/ashfeld/hollowcrown && docker compose up --build -d
cd ~/ashfeld/darkhorn && docker compose up --build -d
cd ~
```

Both projects can run simultaneously on the same host without port conflicts.

---

## Firewall

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

## Useful commands

### View logs

```bash
# All services
docker compose logs -f

# Single service
docker compose logs -f <service_name>
```

**hollowcrown** service names: `hollowcrown-api` `hollowcrown-web` `hollowcrown-db`

**darkhorn** service names: `darkhorn-rest` `darkhorn-postgres` `darkhorn-ldap` `darkhorn-sftp` `darkhorn-soap` `darkhorn-mq` `darkhorn-rabbitmq`

### Check running containers

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

### Update — keep data

After pulling changes from GitHub:

```bash
cd ~/ashfeld/hollowcrown && git pull && docker compose up --build -d
cd ~/ashfeld/darkhorn && git pull && docker compose up --build -d
cd ~
```

### Update — wipe data

After pulling changes from GitHub, if you want to reset all data:

```bash
cd ~/ashfeld/hollowcrown && git pull && docker compose down -v && docker compose up --build -d
cd ~/ashfeld/darkhorn && git pull && docker compose down -v && docker compose up --build -d
cd ~
```

---

## Uninstalling

```bash
cd ~/ashfeld/hollowcrown && docker compose down -v
cd ~/ashfeld/darkhorn && docker compose down -v
cd ~ && sudo rm -rf ~/ashfeld
```

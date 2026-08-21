# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab reproduces that environment. It is a self-contained infrastructure for building and testing identity provisioning integrations against real backends.

```
.
├── darkhorn/        # Target systems — REST, SOAP, MQ, JDBC, SFTP, LDAP
└── hollowcrown/     # HR source system — employee records, web UI
```

Each project has its own `docker-compose.yml` and runs independently.

---

## Projects

### darkhorn

Six backend services, each exposing the same 13 identity operations over a different protocol:

| Backend | Protocol | Port |
|---|---|---|
| `darkhorn-rest` | HTTP REST + Basic Auth / API Key / OIDC | `3000` |
| `darkhorn-soap` | SOAP/WSDL + WS-Security | `3002` |
| `darkhorn-mq` | AMQP request/reply (RabbitMQ) | `5672` |
| `darkhorn-jdbc` | Direct PostgreSQL | `5432` |
| `darkhorn-sftp` | SFTP with CSV files | `2222` |
| `darkhorn-ldap` | OpenLDAP | `389` |

→ See [`darkhorn/README.md`](darkhorn/README.md) for credentials, endpoint reference and data contract examples.

### hollowcrown

A fictional HR system that acts as the upstream source of employee identity data. Includes a web UI for managing employees and a REST API that the adapter can poll.

→ See [`hollowcrown/README.md`](hollowcrown/README.md) for the API reference and employee model.

---

## Infrastructure

### VM requirements

The full stack (both projects) runs comfortably on a single VM.

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 40 GB |

If running only one project, the minimums are lower (2 GB RAM, 15 GB disk for darkhorn alone).

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

**Option A — SCP**

```bash
ssh user@server 'mkdir -p ~/ashfeld/darkhorn ~/ashfeld/hollowcrown'
scp -r ./darkhorn/.    user@server:~/ashfeld/darkhorn
scp -r ./hollowcrown/. user@server:~/ashfeld/hollowcrown
```

**Option B — git clone**

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

---

## Starting each project

```bash
# darkhorn
cd ~/ashfeld/darkhorn
docker compose up --build -d

# hollowcrown
cd ~/ashfeld/hollowcrown
docker compose up --build -d
```

Both projects can run simultaneously on the same host without port conflicts.

---

## Firewall

```bash
sudo ufw allow 22/tcp       # SSH — always first
sudo ufw allow 3000/tcp     # REST
sudo ufw allow 2222/tcp     # SFTP
sudo ufw allow 3002/tcp     # SOAP
sudo ufw allow 5432/tcp     # JDBC / PostgreSQL
sudo ufw allow 5672/tcp     # AMQP
sudo ufw allow 15672/tcp    # RabbitMQ Management UI
sudo ufw allow 389/tcp      # LDAP
sudo ufw allow 8080/tcp     # hollowcrown web UI
sudo ufw enable
```

---

## Useful commands

### Check running containers

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

### Update — keep data

After pulling changes from GitHub:

```bash
# darkhorn
cd ~/ashfeld/darkhorn
git pull
docker compose up --build -d

# hollowcrown
cd ~/ashfeld/hollowcrown
git pull
docker compose up --build -d
```

### Update — wipe data

After pulling changes from GitHub, if you want to reset all data:

```bash
# darkhorn
cd ~/ashfeld/darkhorn
git pull
docker compose down -v
docker compose up --build -d

# hollowcrown
cd ~/ashfeld/hollowcrown
git pull
docker compose down -v
docker compose up --build -d
```

### View logs

```bash
# All services
docker compose logs -f

# Single service
docker compose logs -f hollowcrown-api
docker compose logs -f darkhorn-rest
```

---

## Uninstalling

```bash
cd ~/ashfeld/darkhorn && docker compose down -v
cd ~/ashfeld/hollowcrown && docker compose down -v
cd ~ && sudo rm -rf ~/ashfeld
```

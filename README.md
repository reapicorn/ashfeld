# ashfeld

> **This is a fictional lab environment.** Ashfeld, its districts, organizations, and all data within are entirely invented. Any resemblance to real companies, people, or systems is coincidental. Credentials and secrets committed to this repository are for lab use only and have no value outside of it.

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab puts you in the city and gives you the keys. The backends are real, the protocols are live, and the data is already there waiting. You are not reading about identity provisioning — you are doing it, against systems that behave the way systems behave in the real world: inconsistently, on their own terms, without a common standard in sight.

```
.
├── hollowcrown/     # the bureau — citizen records, the only list anyone agrees to use
└── darkhorn/        # the district — six companies, six protocols, none of them compatible
```

---

## Projects

### Hollowcrown

Hollowcrown was the council that governed Ashfeld before it dissolved. The name passed to the bureau that kept its records. Every citizen who was ever hired, transferred, or terminated has an entry here. What the bureau records, the rest of the city is supposed to reflect.

→ See [`hollowcrown/README.md`](hollowcrown/README.md)

### Darkhorn

Six companies settled in the Darkhorn district after the foundries closed. None of them inherited the same systems. None of them agreed to standardize. They each handle the same three questions — who works here, what do they have access to, are they still active — and they each answer in a different language.

→ See [`darkhorn/README.md`](darkhorn/README.md) — the six companies, their doors, and what moves across the wire.

---

## The flow

```
Hollowcrown (HR feed)  →  adapter  →  Darkhorn (six target systems)
```

Hollowcrown is the authoritative source of identity. When a citizen joins, leaves, or changes roles, Hollowcrown records it. Your adapter reads those events and propagates them — as the correct operation, over the correct protocol — to each of the six backends in Darkhorn.

| JLM event | Business event | IAM action |
|---|---|---|
| **Joiner** | New hire | Provision |
| **Leaver** | Resignation or termination | Deprovision |
| **Mover** | Leave of absence | Suspend |
| **Mover** | Role or department change | Modify |

---

## Requirements

| | RAM | CPU | Disk |
|---|---|---|---|
| Hollowcrown | 512 MB | 1 vCPU | 5 GB |
| Darkhorn | 1 GB | 1 vCPU | 10 GB |
| **Both together** | **2 GB** | **2 vCPU** | **15 GB** |

Disk includes Docker images and data volumes. All containers have explicit memory limits defined in their `docker-compose.yml`.

---

## Prerequisites

Docker and Docker Compose are required.

**Install Docker Desktop:** [docs.docker.com/get-docker](https://docs.docker.com/get-docker/)

> [!WARNING]
> Do not clone this repository inside a OneDrive-synced folder. Docker bind mounts and volume operations can fail when files are locked by OneDrive. Clone to a local path such as `~/ashfeld` or `C:\Labs\ashfeld`.

---

## Starting the lab

Each project is independent. Start them in any order.

### Hollowcrown

```bash
cd hollowcrown
docker compose up -d
```

| Service | URL |
|---|---|
| Web UI | `http://localhost:8080` |
| API | `http://localhost:4000` |

### Darkhorn

```bash
cd darkhorn
docker compose up -d
```

| Service | URL / Host |
|---|---|
| REST | `http://localhost:3000` |
| JDBC | `localhost:5432` |
| LDAP | `localhost:389` |
| SFTP | `localhost:2222` |
| SOAP | `http://localhost:3002` |
| MQ (AMQP) | `localhost:5672` |
| RabbitMQ mgmt | `http://localhost:15672` |

---

## Clone

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

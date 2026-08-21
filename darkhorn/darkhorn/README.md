# darkhorn

A practice environment for developing IVIG adapters, built to work against real backends using the protocols and authentication methods found in production projects.

---

## Purpose

Cover the full lifecycle of an IVIG adapter: from infrastructure to functional integration. Each backend exposes the same set of operations over a different protocol, making it possible to practice the same integration logic in different contexts.

### Practice areas

| Area | What you practice |
|---|---|
| **Flat files (SFTP)** | Download/upload CSV files via SFTP, key-based and password authentication |
| **JDBC** | Direct database connection, reconciliation queries |
| **HTTP REST** | Full CRUD, pagination, suspend/restore, change/reset password — with Basic Auth, API Key and OIDC |
| **LDAP** | Search, attribute reading, group membership, bind with service account |
| **SOAP** | WSDL, document/literal, WS-Security UsernameToken, fault handling |
| **MQ** | AMQP request/reply, correlationId, replyTo, JSON message format |

---

## The challenge

Each section is a prerequisite for the next.

### 1. Set up the VM

The stack runs six containers simultaneously (PostgreSQL, RabbitMQ, OpenLDAP, three Node.js services and a worker). These are the actual resource requirements:

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 2 GB | 4 GB |
| Disk | 15 GB | 30 GB |

**Operating system:**

| OS | Notes |
|---|---|
| **Debian 12 (Bookworm)** | Recommended. Minimal image (~200 MB), stable, supported until 2028. Official Docker available. |
| Ubuntu Server 22.04 LTS | Good alternative. More overhead (~400 MB), more documentation available. |
| Alpine Linux | Not recommended for this stack. The `osixia/openldap` image requires glibc and fails on Alpine. |

---

### 2. Install Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker
```

---

### 3. Deploy the backends

```bash
# Option A: SCP
scp -r ./darkhorn/. user@server:~/darkhorn

# Option B: git clone
git clone <repo-url> ~/darkhorn

ssh user@server
cd ~/darkhorn
cp .env.example .env
docker compose up -d
```

The stack automatically brings up six backends:

| Backend | Protocol | Port |
|---|---|---|
| `darkhorn-rest` | HTTP REST + Basic/APIKey/OIDC | `3000` |
| `darkhorn-jdbc` | Direct JDBC (PostgreSQL) | `5432` |
| `darkhorn-sftp` | SFTP | `2222` |
| `darkhorn-soap` | SOAP/WSDL + WS-Security | `3002` |
| `darkhorn-mq` | AMQP request/reply (RabbitMQ) | `5672` |
| `darkhorn-ldap` | LDAP | `389` |

The seeder runs automatically and loads **150 users + 50 groups** into each database backend.

**LDAP seed** (once, after the container is up):

```bash
node ldap/scripts/generate-seed-ldif.js

docker exec -i darkhorn-ldap ldapadd -x \
  -D 'cn=admin,dc=darkhorn,dc=local' \
  -w 'Bl4ckTr33Admin!' < ldap/bootstrap/02-users.ldif

docker exec -i darkhorn-ldap ldapadd -x \
  -D 'cn=admin,dc=darkhorn,dc=local' \
  -w 'Bl4ckTr33Admin!' < ldap/bootstrap/03-groups.ldif
```

**Firewall:**

```bash
sudo ufw allow 22/tcp      # SSH — always first
sudo ufw allow 3000/tcp
sudo ufw allow 2222/tcp
sudo ufw allow 3002/tcp
sudo ufw allow 5432/tcp
sudo ufw allow 5672/tcp
sudo ufw allow 15672/tcp
sudo ufw allow 389/tcp
sudo ufw enable
```

**Re-run the seed:**

```bash
# PostgreSQL (all backends)
docker compose run --rm seed

# LDAP
node ldap/scripts/generate-seed-ldif.js
docker exec -i darkhorn-ldap ldapadd -x \
  -D 'cn=admin,dc=darkhorn,dc=local' \
  -w 'Bl4ckTr33Admin!' < ldap/bootstrap/02-users.ldif
docker exec -i darkhorn-ldap ldapadd -x \
  -D 'cn=admin,dc=darkhorn,dc=local' \
  -w 'Bl4ckTr33Admin!' < ldap/bootstrap/03-groups.ldif
```

---

### 4. Validate the deployment

Verify that each backend responds correctly before moving on.

#### darkhorn-rest

```bash
# Health (no auth)
curl -s http://<host>:3000/api/health

# Basic Auth
curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/users?count=3'

# API Key
curl -s -H 'X-API-Key: sh4d0wh0rn-4p1-k3y-d4rkn3ss' \
  'http://<host>:3000/api/users?count=3'

# OIDC — get token
TOKEN=$(curl -s -X POST http://<host>:3000/oauth/token \
  -d 'grant_type=client_credentials' \
  -d 'client_id=voidhorn' \
  -d 'client_secret=v01dh0rn$3cr3t!' \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# OIDC — use token
curl -s -H "Authorization: Bearer $TOKEN" \
  'http://<host>:3000/api/users?count=3'
```

#### darkhorn-sftp

```bash
sftp spectral@<host> -P 2222
# password: Sp3ctr4lF1l3!
sftp> ls darkhorn/
sftp> get darkhorn/users.csv
```

#### darkhorn-soap

```bash
# WSDL
curl -s 'http://<host>:3002/soap?wsdl' | head -10

# LookupUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "LookupUser"' \
  -d '<?xml version="1.0"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:tns="http://darkhorn.local/userservice">
  <soapenv:Header/>
  <soapenv:Body>
    <tns:LookupUserRequest>
      <tns:id>john.smith</tns:id>
    </tns:LookupUserRequest>
  </soapenv:Body>
</soapenv:Envelope>'
```

#### darkhorn-jdbc

```bash
docker exec -it darkhorn-postgres psql \
  -U darkhorn -d darkhorn_jdbc \
  -c "SELECT username, email, status FROM users LIMIT 5;"
```

#### darkhorn-mq

```bash
rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='' \
  routing_key='darkhorn.requests' \
  payload='{"operation":"SearchUsers","payload":{"count":3}}'
```

Or from the Management UI at `http://<host>:15672` (user: `darkhorn`, password: `Wr41thPuls3!`).

#### darkhorn-ldap

```bash
ldapsearch -x \
  -H ldap://<host>:389 \
  -D 'cn=svc-darkhorn,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=People,dc=darkhorn,dc=local' \
  '(objectClass=inetOrgPerson)' uid cn mail \
  | head -30
```

---

### 5. Explore the data contract

Before building the adapter, operate the backends manually to understand exactly what data is sent and received in each operation.

#### Create, suspend and restore a user (REST)

```bash
# Create
curl -s -X POST http://<host>:3000/api/users \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{
    "username":   "test.user",
    "email":      "test.user@darkhorn.local",
    "firstName":  "Test",
    "lastName":   "User",
    "password":   "Passw0rd!",
    "department": "IT",
    "title":      "Engineer"
  }'

# Get id
ID=$(curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/users/test.user' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

# Suspend / restore
curl -s -X POST http://<host>:3000/api/users/$ID/suspend -u grimreaper:'Wh1sp3r0fD4rk!'
curl -s -X POST http://<host>:3000/api/users/$ID/restore -u grimreaper:'Wh1sp3r0fD4rk!'

# Reset password
curl -s -X POST http://<host>:3000/api/users/$ID/reset-password \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"newPassword": "N3wPassw0rd!"}'

# Assign groups
curl -s -X POST http://<host>:3000/api/users/$ID/groups \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"groupNames": ["admins", "developers"]}'
```

#### Create an LDAP entry

```bash
cat > /tmp/new-user.ldif << 'EOF'
dn: uid=test.user,ou=People,dc=darkhorn,dc=local
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
uid: test.user
cn: Test User
sn: User
givenName: Test
mail: test.user@darkhorn.local
userPassword: Passw0rd!
departmentNumber: IT
title: Engineer
EOF

ldapadd -x \
  -H ldap://<host>:389 \
  -D 'cn=admin,dc=darkhorn,dc=local' \
  -w 'Bl4ckTr33Admin!' \
  -f /tmp/new-user.ldif
```

#### Send an operation via MQ

```bash
rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='' \
  routing_key='darkhorn.requests' \
  payload='{
    "operation": "AddUser",
    "payload": {
      "username":   "mq.user",
      "email":      "mq.user@darkhorn.local",
      "firstName":  "MQ",
      "lastName":   "User",
      "password":   "Passw0rd!",
      "department": "DevOps",
      "title":      "Engineer"
    }
  }'
```

---

### 6. Build the adapter

With the backends validated and the data contract understood, the final step is to build the IVIG adapter. Each backend is designed to exercise a different connector type: HTTP/REST, JDBC, SOAP, MQ and LDAP.

---

## Service credentials

### darkhorn-rest (port 3000)

| Method | Identifier | Credential |
|---|---|---|
| Basic Auth | `grimreaper` | `Wh1sp3r0fD4rk!` |
| API Key | `shadowhorn-key` | `sh4d0wh0rn-4p1-k3y-d4rkn3ss` |
| OIDC client_id | `voidhorn` | `v01dh0rn$3cr3t!` |

### darkhorn-jdbc (port 5432)

| Parameter | Value |
|---|---|
| JDBC URL | `jdbc:postgresql://<host>:5432/darkhorn_jdbc` |
| Driver | `org.postgresql.Driver` |
| Username | `darkhorn` |
| Password | `Sp3ct3r0fN1ght!` |

### darkhorn-sftp (port 2222)

| Parameter | Value |
|---|---|
| Host | `<host>` |
| Port | `2222` |
| Username | `spectral` |
| Password | `Sp3ctr4lF1l3!` |
| Remote path | `/darkhorn` |
| Files | `users.csv`, `groups.csv`, `user_groups.csv` |

### darkhorn-soap (port 3002)

| Parameter | Value |
|---|---|
| Endpoint | `http://<host>:3002/soap` |
| WSDL | `http://<host>:3002/soap?wsdl` |
| WS-Security user | `banshee` |
| WS-Security password | `B4nsh33Sc4ms!` |

### darkhorn-mq (AMQP port 5672)

| Parameter | Value |
|---|---|
| AMQP URL | `amqp://darkhorn:Wr41thPuls3!@<host>:5672` |
| Queue | `darkhorn.requests` |
| Management UI | `http://<host>:15672` |

### darkhorn-ldap (port 389)

| Parameter | Value |
|---|---|
| Base DN | `dc=darkhorn,dc=local` |
| People DN | `ou=People,dc=darkhorn,dc=local` |
| Groups DN | `ou=Groups,dc=darkhorn,dc=local` |
| Service account | `cn=svc-darkhorn,ou=People,dc=darkhorn,dc=local` |
| Service password | `Sp3ctr3Qu13t!` |
| Admin DN | `cn=admin,dc=darkhorn,dc=local` |
| Admin password | `Bl4ckTr33Admin!` |

---

## Endpoint and operation reference

All backends implement the same set of 13 operations. Details by protocol below.

### darkhorn-rest — HTTP REST (port 3000)

| Method | Endpoint | Operation |
|---|---|---|
| `GET` | `/api/health` | Health check (no auth) |
| `POST` | `/api/users` | Add |
| `PUT` | `/api/users/:id` | Modify |
| `DELETE` | `/api/users/:id` | Delete |
| `GET` | `/api/users/:id` | Lookup |
| `GET` | `/api/users` | Search / Reconcile |
| `POST` | `/api/users/:id/suspend` | Suspend |
| `POST` | `/api/users/:id/restore` | Restore |
| `POST` | `/api/users/:id/change-password` | Change Password |
| `POST` | `/api/users/:id/reset-password` | Reset Password |
| `GET` | `/api/groups` | Get Groups |
| `GET` | `/api/users/:id/groups` | Get User Groups |
| `POST` | `/api/users/:id/groups` | Assign Groups |
| `DELETE` | `/api/users/:id/groups` | Remove Groups |
| `GET` | `/.well-known/openid-configuration` | OIDC Discovery |
| `GET` | `/.well-known/jwks.json` | JWKS |
| `POST` | `/oauth/token` | Token (client_credentials / password) |
| `GET` | `/oauth/userinfo` | Userinfo |

### darkhorn-sftp — SFTP (port 2222)

Files available under the remote path `/darkhorn`:

| File | Contents |
|---|---|
| `users.csv` | One row per user — `id`, `username`, `email`, `firstName`, `lastName`, `password`, `status`, `department`, `title`, `createdAt`, `updatedAt` |
| `groups.csv` | One row per group — `id`, `name`, `description`, `createdAt` |
| `user_groups.csv` | Membership — `userId`, `groupId` |

The adapter reads and writes these files directly over SFTP. Each operation maps to a read-modify-write cycle on the relevant CSV.

### darkhorn-jdbc — Direct PostgreSQL (port 5432)

Database: `darkhorn_jdbc`. Operations are implemented as SQL queries against the shared schema.

| Table | Purpose |
|---|---|
| `users` | Users — Add, Modify, Delete, Lookup, Search, Suspend, Restore, Change/Reset Password |
| `groups` | Groups — Get Groups |
| `user_groups` | Membership — Get/Assign/Remove Groups |

Key columns on `users`: `id`, `username`, `email`, `first_name`, `last_name`, `password`, `status` (`active`/`suspended`), `department`, `title`, `password_reset_at`, `created_at`, `updated_at`.

### darkhorn-soap — SOAP/WSDL (port 3002)

Endpoint: `http://<host>:3002/soap` · WSDL: `http://<host>:3002/soap?wsdl`

| SOAP Operation | Key input parameters |
|---|---|
| `AddUser` | `username`, `email`, `firstName`, `lastName`, `password`, `department`, `title` |
| `ModifyUser` | `id` + fields to update |
| `DeleteUser` | `id` |
| `LookupUser` | `id` |
| `SearchUsers` | `username`, `email`, `firstName`, `lastName`, `status`, `startIndex`, `count` |
| `SuspendUser` | `id` |
| `RestoreUser` | `id` |
| `ChangePassword` | `id`, `currentPassword`, `newPassword` |
| `ResetPassword` | `id`, `newPassword` |
| `GetGroups` | — |
| `GetUserGroups` | `userId` |
| `AssignGroups` | `userId`, `groupIds[]` / `groupNames[]` |
| `RemoveGroups` | `userId`, `groupIds[]` / `groupNames[]` |

### darkhorn-mq — AMQP request/reply (port 5672)

Queue: `darkhorn.requests`. Message format:

```json
{
  "operation": "<name>",
  "payload":   { }
}
```

Response delivered to the queue specified in `replyTo`, correlated via `correlationId`:

```json
{ "status": "ok",    "data":  { } }
{ "status": "error", "error": { "code": "...", "message": "..." } }
```

Operations and their `payload` fields are identical to the SOAP input parameters in the table above.

### darkhorn-ldap — LDAP (port 389)

| Operation | LDAP equivalent |
|---|---|
| Add | `ldapadd` — new `inetOrgPerson` entry under `ou=People` |
| Modify | `ldapmodify` — attributes `cn`, `sn`, `givenName`, `mail`, `departmentNumber`, `title` |
| Delete | `ldapdelete` — remove entry by DN |
| Lookup | `ldapsearch` — filter `(uid=<username>)` |
| Search / Reconcile | `ldapsearch` — filter `(objectClass=inetOrgPerson)` with optional attributes |
| Suspend | `ldapmodify` — add `description: suspended` |
| Restore | `ldapmodify` — remove `description` attribute |
| Change / Reset Password | `ldapmodify` — replace `userPassword` |
| Get Groups | `ldapsearch` — base `ou=Groups`, filter `(objectClass=groupOfNames)` |
| Get User Groups | `ldapsearch` — filter `(member=uid=<user>,ou=People,...)` |
| Assign Groups | `ldapmodify` — add `member` to group |
| Remove Groups | `ldapmodify` — remove `member` from group |

User object attributes (`inetOrgPerson`): `uid`, `cn`, `sn`, `givenName`, `mail`, `userPassword`, `departmentNumber`, `title`, `description`.

---

## Project structure

```
darkhorn/
├── docker-compose.yml
├── .env.example
├── db/
│   ├── schema.sql             # Shared schema (users, groups, user_groups)
│   ├── init-db.sh             # Creates the 4 PostgreSQL databases and applies schema
│   ├── seed.js                # 150 users + 50 groups per database
│   ├── package.json
│   └── Dockerfile.seed
├── rest/                      # darkhorn-rest  — HTTP REST + Basic/APIKey/OIDC
│   ├── Dockerfile
│   ├── package.json
│   ├── config.json
│   └── src/
│       ├── index.js
│       ├── config.js
│       ├── auth/              # keys.js, oidc.js, middleware.js
│       ├── routes/            # users.js, passwords.js, groups.js
│       ├── middleware/        # errorHandler.js
│       └── persistence/       # store.js (PostgreSQL)
├── sftp/                      # darkhorn-sftp — SFTP server (atmoz/sftp)
│   ├── Dockerfile.seed
│   ├── package.json
│   └── seed.js                # Generates users.csv, groups.csv, user_groups.csv
├── soap/                      # darkhorn-soap  — SOAP/WSDL
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── index.js           # SOAP server + Express health endpoint
│       ├── store.js           # PostgreSQL
│       └── service.wsdl       # Full WSDL with all 13 operations
├── mq/                        # darkhorn-mq    — RabbitMQ worker
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── worker.js          # AMQP consumer + dispatcher
│       └── store.js           # PostgreSQL
├── ldap/
│   ├── bootstrap/
│   │   ├── 01-structure.ldif  # ou=People, ou=Groups, service account
│   │   ├── 02-users.ldif      # 150 inetOrgPerson (generated)
│   │   └── 03-groups.ldif     # 50 groupOfNames (generated)
│   └── scripts/
│       ├── generate-seed-ldif.js
│       └── seed-ldap.sh
└── jdbc/
    └── jdbc.properties        # JDBC configuration for the adapter
```
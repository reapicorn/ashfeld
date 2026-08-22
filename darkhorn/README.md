# darkhorn

Darkhorn is the southern district of Ashfeld, built around the old processing yards and the warehouses that outlasted them. The companies that moved in after the foundries closed brought their own ways of doing things — their own ledgers, their own couriers, their own gates. None of it was designed to connect. It just grew, one system at a time, until untangling it became someone else's problem.

Each backend in this project exposes the same set of 13 identity operations over a different protocol, making it possible to practice the same integration logic in different contexts:

`Search users` · `Lookup user` · `Create user` · `Modify user` · `Delete user` · `Suspend user` · `Restore user` · `Change password` · `Reset password` · `Get groups` · `Get user groups` · `Assign groups` · `Remove groups`

---

## Purpose

### Practice areas

| Area | What you practice |
|---|---|
| **HTTP REST** | Full CRUD, pagination, suspend/restore, change/reset password — with Basic Auth, API Key and OIDC |
| **JDBC** | Direct database connection, reconciliation queries |
| **LDAP** | Search, attribute reading, group membership, bind with service account |
| **Flat files (SFTP)** | Download/upload CSV files via SFTP, key-based and password authentication |
| **SOAP** | WSDL, document/literal, WS-Security UsernameToken, fault handling |
| **MQ** | AMQP request/reply, correlationId, replyTo, JSON message format |

---

## Service credentials

### darkhorn-rest

| Method | Identifier | Credential |
|---|---|---|
| Basic Auth | `grimreaper` | `Wh1sp3r0fD4rk!` |
| API Key | `shadowhorn-key` | `sh4d0wh0rn-4p1-k3y-d4rkn3ss` |
| OIDC client_id | `voidhorn` | `v01dh0rn$3cr3t!` |

| URL | |
|---|---|
| Base | `http://<host>:3000` |
| OIDC token | `http://<host>:3000/oauth/token` |
| OIDC discovery | `http://<host>:3000/.well-known/openid-configuration` |

### darkhorn-jdbc

| Parameter | Value |
|---|---|
| JDBC URL | `jdbc:postgresql://<host>:5432/darkhorn_jdbc` |
| Driver | `org.postgresql.Driver` |
| Username | `darkhorn` |
| Password | `Sp3ct3r0fN1ght!` |

### darkhorn-ldap

| Parameter | Value |
|---|---|
| Base DN | `dc=darkhorn,dc=local` |
| Users DN | `ou=Users,dc=darkhorn,dc=local` |
| Groups DN | `ou=Groups,dc=darkhorn,dc=local` |
| Service account | `cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local` |
| Service password | `Sp3ctr3Qu13t!` |
| Admin DN | `uid=admin,dc=darkhorn,dc=local` |
| Admin password | `Bl4ckTr33Admin!` |

### darkhorn-sftp

| Parameter | Value |
|---|---|
| Port | `2222` |
| Username | `spectral` |
| Password | `Sp3ctr4lF1l3!` |
| Remote path | `/darkhorn` |
| Files | `users.csv`, `groups.csv`, `user_groups.csv` |

### darkhorn-soap

| Parameter | Value |
|---|---|
| Endpoint | `http://<host>:3002/soap` |
| WSDL | `http://<host>:3002/soap?wsdl` |
| WS-Security user | `banshee` |
| WS-Security password | `B4nsh33Sc4ms!` |

### darkhorn-mq

| Parameter | Value |
|---|---|
| AMQP URL | `amqp://darkhorn:Wr41thPuls3!@<host>:5672` |
| Queue | `darkhorn.requests` |
| Management UI | `http://<host>:15672` |

---

## The challenge

### 1. Get familiar with the backends

Confirm each backend is reachable and understand how it communicates before building against it.

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

#### darkhorn-jdbc

```bash
docker exec -it darkhorn-postgres psql -h <host> -U darkhorn -d darkhorn_jdbc \
  -c "SELECT username, email, status FROM users LIMIT 5;"
```

#### darkhorn-ldap

```bash
docker exec -it darkhorn-ldap ldapsearch -x \
  -H ldap://localhost:389 \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Users,dc=darkhorn,dc=local' \
  '(objectClass=inetOrgPerson)' uid cn mail \
  | head -30
```

#### darkhorn-sftp

```bash
sftp -P 2222 spectral@<host>
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
      <tns:id>james.smith</tns:id>
    </tns:LookupUserRequest>
  </soapenv:Body>
</soapenv:Envelope>'
```

> Tip: append `'| xmllint --format -'` to any `curl` command for readable XML output.

#### darkhorn-mq

The worker accepts messages on `darkhorn.requests` and replies to the queue named in `reply_to`. It processes each message after a random delay of 1–60 seconds.

Validate the full request/reply cycle:

```bash
# 1. Create a temporary reply queue
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' \
  declare queue name=my-reply-queue durable=false

# 2. Publish a request with reply_to and correlation_id
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  properties='{"reply_to":"my-reply-queue","correlation_id":"test-1"}' \
  payload='{"operation":"SearchUsers","payload":{"count":3}}'

# 3. Wait up to 60 s, then read the response
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' \
  get queue=my-reply-queue

# 4. Delete the reply queue
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' \
  delete queue name=my-reply-queue
```

---

### 2. Build the connector

With the backends validated and the data contract understood, build the connector against each backend. Each service is designed to exercise a different connector type: HTTP/REST, JDBC, SOAP, MQ and LDAP.

---

## Data contract examples

Before building the connector, operate the backends manually to understand exactly what data is sent and received in each operation.

#### darkhorn-rest — HTTP REST

```bash
# Search users
curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/users?count=3' | jq .

# Lookup user
curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/users/test.user' | jq .

# Create user
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

# Capture the generated id
ID=$(curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/users/test.user' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

# Modify user
curl -s -X PUT http://<host>:3000/api/users/$ID \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"title": "Senior Engineer", "department": "DevOps"}'

# Suspend / restore
curl -s -X POST http://<host>:3000/api/users/$ID/suspend  -u grimreaper:'Wh1sp3r0fD4rk!'
curl -s -X POST http://<host>:3000/api/users/$ID/restore  -u grimreaper:'Wh1sp3r0fD4rk!'

# Change password
curl -s -X POST http://<host>:3000/api/users/$ID/change-password \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"currentPassword": "Passw0rd!", "newPassword": "N3wPassw0rd!"}'

# Reset password
curl -s -X POST http://<host>:3000/api/users/$ID/reset-password \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"newPassword": "N3wPassw0rd!"}'

# Get groups
curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  'http://<host>:3000/api/groups' | jq .

# Get user groups
curl -s -u grimreaper:'Wh1sp3r0fD4rk!' \
  "http://<host>:3000/api/users/$ID/groups" | jq .

# Assign groups
curl -s -X POST http://<host>:3000/api/users/$ID/groups \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"groupNames": ["admins", "developers"]}'

# Remove groups
curl -s -X DELETE http://<host>:3000/api/users/$ID/groups \
  -u grimreaper:'Wh1sp3r0fD4rk!' \
  -H 'Content-Type: application/json' \
  -d '{"groupNames": ["developers"]}'

# Delete user
curl -s -X DELETE http://<host>:3000/api/users/$ID -u grimreaper:'Wh1sp3r0fD4rk!'
```

#### darkhorn-jdbc — PostgreSQL

```bash
# Connect directly to the darkhorn_jdbc database
docker exec -it darkhorn-postgres psql -h <host> -U darkhorn -d darkhorn_jdbc
```

```sql
-- Search users
SELECT id, username, email, first_name, last_name, status, department FROM users
ORDER BY last_name LIMIT 10;

-- Lookup user
SELECT * FROM users WHERE username = 'sql.user';

-- Add a user
INSERT INTO users (id, username, email, first_name, last_name, password, status, department, title)
VALUES (gen_random_uuid(), 'sql.user', 'sql.user@darkhorn.local',
        'SQL', 'User', crypt('Passw0rd!', gen_salt('bf')), 'active', 'IT', 'Engineer');

-- Modify user
UPDATE users SET title = 'Senior Engineer', department = 'DevOps', updated_at = NOW()
WHERE username = 'sql.user';

-- Suspend
UPDATE users SET status = 'suspended', updated_at = NOW()
WHERE username = 'sql.user';

-- Restore
UPDATE users SET status = 'active', updated_at = NOW()
WHERE username = 'sql.user';

-- Change password (requires current password check in application logic — SQL sets directly)
UPDATE users SET password = crypt('N3wPassw0rd!', gen_salt('bf')), updated_at = NOW()
WHERE username = 'sql.user';

-- Reset password
UPDATE users SET password = crypt('N3wPassw0rd!', gen_salt('bf')), password_reset_at = NOW(), updated_at = NOW()
WHERE username = 'sql.user';

-- Get groups
SELECT id, name, description FROM groups ORDER BY name;

-- Get user groups
SELECT g.id, g.name FROM groups g
JOIN user_groups ug ON ug.group_id = g.id
JOIN users u ON u.id = ug.user_id
WHERE u.username = 'sql.user';

-- Assign groups
INSERT INTO user_groups (user_id, group_id)
SELECT u.id, g.id FROM users u, groups g
WHERE u.username = 'sql.user' AND g.name IN ('admins', 'developers')
ON CONFLICT DO NOTHING;

-- Remove groups
DELETE FROM user_groups
WHERE user_id = (SELECT id FROM users WHERE username = 'sql.user')
  AND group_id IN (SELECT id FROM groups WHERE name IN ('developers'));

-- Delete user
DELETE FROM users WHERE username = 'sql.user';
```

#### darkhorn-ldap — LDAP

```bash
# Search users
ldapsearch -x \
  -H ldap://<host>:389 \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Users,dc=darkhorn,dc=local' \
  -z 3 \
  '(objectClass=inetOrgPerson)' uid cn mail

# Lookup user
ldapsearch -x \
  -H ldap://<host>:389 \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Users,dc=darkhorn,dc=local' \
  '(uid=test.user)'

# Add a user
cat > /tmp/new-user.ldif << 'EOF'
dn: uid=test.user,ou=Users,dc=darkhorn,dc=local
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

ldapadd -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' \
  -f /tmp/new-user.ldif

# Modify user
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: uid=test.user,ou=Users,dc=darkhorn,dc=local
changetype: modify
replace: title
title: Senior Engineer
-
replace: departmentNumber
departmentNumber: DevOps
EOF

# Suspend (add description: suspended)
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: uid=test.user,ou=Users,dc=darkhorn,dc=local
changetype: modify
add: description
description: suspended
EOF

# Restore (remove description attribute)
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: uid=test.user,ou=Users,dc=darkhorn,dc=local
changetype: modify
delete: description
EOF

# Change password (requires current password via ldappasswd)
ldappasswd -x \
  -H ldap://<host>:389 \
  -D 'uid=test.user,ou=Users,dc=darkhorn,dc=local' \
  -w 'Passw0rd!' \
  -s 'N3wPassw0rd!' \
  'uid=test.user,ou=Users,dc=darkhorn,dc=local'

# Reset password (admin sets directly)
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: uid=test.user,ou=Users,dc=darkhorn,dc=local
changetype: modify
replace: userPassword
userPassword: N3wPassw0rd!
EOF

# Get groups
ldapsearch -x \
  -H ldap://<host>:389 \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Groups,dc=darkhorn,dc=local' \
  '(objectClass=groupOfNames)' cn description

# Get user groups
ldapsearch -x \
  -H ldap://<host>:389 \
  -D 'cn=svc-darkhorn,ou=Users,dc=darkhorn,dc=local' \
  -w 'Sp3ctr3Qu13t!' \
  -b 'ou=Groups,dc=darkhorn,dc=local' \
  '(member=uid=test.user,ou=Users,dc=darkhorn,dc=local)' cn

# Assign to a group
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: cn=admins,ou=Groups,dc=darkhorn,dc=local
changetype: modify
add: member
member: uid=test.user,ou=Users,dc=darkhorn,dc=local
EOF

# Remove from a group
ldapmodify -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' << 'EOF'
dn: cn=admins,ou=Groups,dc=darkhorn,dc=local
changetype: modify
delete: member
member: uid=test.user,ou=Users,dc=darkhorn,dc=local
EOF

# Delete user
ldapdelete -x -H ldap://<host>:389 \
  -D 'uid=admin,dc=darkhorn,dc=local' -w 'Bl4ckTr33Admin!' \
  'uid=test.user,ou=Users,dc=darkhorn,dc=local'
```

#### darkhorn-sftp — SFTP

```bash
# Connect and list files
sftp -P 2222 spectral@<host>
# password: Sp3ctr4lF1l3!
sftp> ls darkhorn/
sftp> get darkhorn/users.csv
sftp> get darkhorn/groups.csv
sftp> get darkhorn/user_groups.csv

# Inspect the users file (first 3 data rows)
head -4 users.csv
# id,username,email,firstName,lastName,password,status,department,title,createdAt,updatedAt

# Manually add a row, then upload the modified file
sftp> put users.csv darkhorn/users.csv
```

#### darkhorn-soap — SOAP/WSDL

The WS-Security header is required on every request. A reusable helper variable makes the examples shorter:

```bash
# Shared WS-Security header fragment (used in all examples below)
AUTH='<soapenv:Header>
  <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
    <wsse:UsernameToken>
      <wsse:Username>banshee</wsse:Username>
      <wsse:Password>B4nsh33Sc4ms!</wsse:Password>
    </wsse:UsernameToken>
  </wsse:Security>
</soapenv:Header>'
```

```bash
# SearchUsers — return 3 users
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "SearchUsers"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:SearchUsersRequest>
      <tns:count>3</tns:count>
      <tns:startIndex>0</tns:startIndex>
    </tns:SearchUsersRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# AddUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "AddUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:AddUserRequest>
      <tns:username>soap.user</tns:username>
      <tns:email>soap.user@darkhorn.local</tns:email>
      <tns:firstName>SOAP</tns:firstName>
      <tns:lastName>User</tns:lastName>
      <tns:password>Passw0rd!</tns:password>
      <tns:department>IT</tns:department>
      <tns:title>Engineer</tns:title>
    </tns:AddUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# LookupUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "LookupUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:LookupUserRequest>
      <tns:id>soap.user</tns:id>
    </tns:LookupUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# ModifyUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "ModifyUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:ModifyUserRequest>
      <tns:id>soap.user</tns:id>
      <tns:title>Senior Engineer</tns:title>
    </tns:ModifyUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# SuspendUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "SuspendUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:SuspendUserRequest>
      <tns:id>soap.user</tns:id>
    </tns:SuspendUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# RestoreUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "RestoreUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:RestoreUserRequest>
      <tns:id>soap.user</tns:id>
    </tns:RestoreUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# ChangePassword
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "ChangePassword"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:ChangePasswordRequest>
      <tns:id>soap.user</tns:id>
      <tns:currentPassword>Passw0rd!</tns:currentPassword>
      <tns:newPassword>N3wPassw0rd!</tns:newPassword>
    </tns:ChangePasswordRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# ResetPassword
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "ResetPassword"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:ResetPasswordRequest>
      <tns:id>soap.user</tns:id>
      <tns:newPassword>N3wPassw0rd!</tns:newPassword>
    </tns:ResetPasswordRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# GetGroups
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "GetGroups"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:GetGroupsRequest/>
  </soapenv:Body>
</soapenv:Envelope>"

# GetUserGroups
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "GetUserGroups"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:GetUserGroupsRequest>
      <tns:userId>soap.user</tns:userId>
    </tns:GetUserGroupsRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# AssignGroups
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "AssignGroups"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:AssignGroupsRequest>
      <tns:userId>soap.user</tns:userId>
      <tns:groupNames>admins</tns:groupNames>
      <tns:groupNames>developers</tns:groupNames>
    </tns:AssignGroupsRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# RemoveGroups
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "RemoveGroups"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:RemoveGroupsRequest>
      <tns:userId>soap.user</tns:userId>
      <tns:groupNames>developers</tns:groupNames>
    </tns:RemoveGroupsRequest>
  </soapenv:Body>
</soapenv:Envelope>"

# DeleteUser
curl -s -X POST http://<host>:3002/soap \
  -H 'Content-Type: text/xml;charset=UTF-8' \
  -H 'SOAPAction: "DeleteUser"' \
  -d "<?xml version=\"1.0\"?>
<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\"
                  xmlns:tns=\"http://darkhorn.local/userservice\">
  ${AUTH}
  <soapenv:Body>
    <tns:DeleteUserRequest>
      <tns:id>soap.user</tns:id>
    </tns:DeleteUserRequest>
  </soapenv:Body>
</soapenv:Envelope>"
```

#### darkhorn-mq — AMQP request/reply

All messages are published to the `darkhorn.requests` queue. The worker processes each message after a **random delay of 1–60 seconds**, then sends the response to the queue named in `replyTo`.

This simulates a real asynchronous target system — the adapter must not block waiting for a response, and must correlate replies using `correlationId`.

### Request/reply pattern

```
Adapter                          darkhorn-mq worker
  │                                      │
  ├─ assert reply queue ─────────────────┤
  ├─ publish to darkhorn.requests ───────▶│
  │   replyTo: "my-reply-queue"          │  (waits 1–60 s)
  │   correlationId: "abc-123"           │
  │                                      ├─ processes operation
  │◀─ response in my-reply-queue ────────┤
  │   correlationId: "abc-123"           │
```

**Message properties** (set by the adapter, not in the payload):

| Property | Description |
|---|---|
| `reply_to` | Name of the queue where the response will be sent |
| `correlation_id` | Arbitrary string — echoed back in the response for matching |

**Validate the full cycle:**

```bash
# 1. Create a reply queue
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' \
  declare queue name=my-reply-queue durable=false

# 2. Publish with reply_to and correlation_id
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  properties='{"reply_to":"my-reply-queue","correlation_id":"test-1"}' \
  payload='{"operation":"SearchUsers","payload":{"count":3}}'

# 3. Wait for the response (worker delays 1–60 s)
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' \
  get queue=my-reply-queue
```

### Operation examples

```bash
# SearchUsers — return 3 users
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"SearchUsers","payload":{"count":3}}'

# AddUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
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

# LookupUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"LookupUser","payload":{"id":"mq.user"}}'

# ModifyUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"ModifyUser","payload":{"id":"mq.user","title":"Senior Engineer"}}'

# SuspendUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"SuspendUser","payload":{"id":"mq.user"}}'

# RestoreUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"RestoreUser","payload":{"id":"mq.user"}}'

# ChangePassword
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"ChangePassword","payload":{"id":"mq.user","currentPassword":"Passw0rd!","newPassword":"N3wPassw0rd!"}}'

# ResetPassword
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"ResetPassword","payload":{"id":"mq.user","newPassword":"N3wPassw0rd!"}}'

# GetGroups
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"GetGroups","payload":{}}'

# GetUserGroups
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"GetUserGroups","payload":{"userId":"mq.user"}}'

# AssignGroups
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"AssignGroups","payload":{"userId":"mq.user","groupNames":["admins","developers"]}}'

# RemoveGroups
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"RemoveGroups","payload":{"userId":"mq.user","groupNames":["developers"]}}'

# DeleteUser
docker exec darkhorn-rabbitmq rabbitmqadmin -H <host> -u darkhorn -p 'Wr41thPuls3!' publish \
  exchange='amq.default' routing_key='darkhorn.requests' \
  payload='{"operation":"DeleteUser","payload":{"id":"mq.user"}}'
```

> The examples above omit `reply_to` and `correlation_id` for brevity. In a real adapter, both properties must be set on every message to receive the response.

---

## Endpoint and operation reference

All backends implement the same set of 13 operations — Search users, Lookup user, Create user, Modify user, Delete user, Suspend user, Restore user, Change password, Reset password, Get groups, Get user groups, Assign groups, Remove groups. Details by protocol below.

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

### darkhorn-jdbc — Direct PostgreSQL (port 5432)

Database: `darkhorn_jdbc`. Operations are implemented as SQL queries against the shared schema.

| Table | Purpose |
|---|---|
| `users` | Users — Add, Modify, Delete, Lookup, Search, Suspend, Restore, Change/Reset Password |
| `groups` | Groups — Get Groups |
| `user_groups` | Membership — Get/Assign/Remove Groups |

Key columns on `users`: `id`, `username`, `email`, `first_name`, `last_name`, `password`, `status` (`active`/`suspended`), `department`, `title`, `password_reset_at`, `created_at`, `updated_at`.

### darkhorn-ldap — LDAP (port 389)

| Operation | LDAP equivalent |
|---|---|
| Add | `ldapadd` — new `inetOrgPerson` entry under `ou=Users` |
| Modify | `ldapmodify` — attributes `cn`, `sn`, `givenName`, `mail`, `departmentNumber`, `title` |
| Delete | `ldapdelete` — remove entry by DN |
| Lookup | `ldapsearch` — filter `(uid=<username>)` |
| Search / Reconcile | `ldapsearch` — filter `(objectClass=inetOrgPerson)` with optional attributes |
| Suspend | `ldapmodify` — add `description: suspended` |
| Restore | `ldapmodify` — remove `description` attribute |
| Change / Reset Password | `ldapmodify` — replace `userPassword` |
| Get Groups | `ldapsearch` — base `ou=Groups`, filter `(objectClass=groupOfNames)` |
| Get User Groups | `ldapsearch` — filter `(member=uid=<user>,ou=Users,...)` |
| Assign Groups | `ldapmodify` — add `member` to group |
| Remove Groups | `ldapmodify` — remove `member` from group |

User object attributes (`inetOrgPerson`): `uid`, `cn`, `sn`, `givenName`, `mail`, `userPassword`, `departmentNumber`, `title`, `description`.

### darkhorn-sftp — SFTP (port 2222)

Files available under the remote path `/darkhorn`:

| File | Contents |
|---|---|
| `users.csv` | One row per user — `id`, `username`, `email`, `firstName`, `lastName`, `password`, `status`, `department`, `title`, `createdAt`, `updatedAt` |
| `groups.csv` | One row per group — `id`, `name`, `description`, `createdAt` |
| `user_groups.csv` | Membership — `userId`, `groupId` |

Each operation maps to a read-modify-write cycle on the relevant CSV file.

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


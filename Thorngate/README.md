# Thorngate

Ashfeld was always a city where nobody agreed on who had access to what. The old guilds kept their own lists, their own rules, their own definitions of who counted as a member. When the guilds dissolved, the access went with them — or didn't. Nobody could say for certain.

Thorngate was built to answer that question. It is the city's governance layer — the gate that decides who gets access, to what, and under what conditions. Not because the organizations asked for it, but because the city had become impossible to audit without it. Lifecycle management, role governance, provisioning policies — Thorngate is the engine behind every identity decision in Ashfeld.

---

## Access

| Service | URL |
|---|---|
| IVIG Console | `https://<SERVER_IP>:30943/itim/console` |

| Field | Value |
|---|---|
| Username | `itim manager` |
| Password | `secret` |

Default tenant: `Acme` / org name: `Acme Inc.`

---

## External connections

### PostgreSQL

| Parameter | Value |
|---|---|
| Host | `<SERVER_IP>` |
| Port | `30543` |
| Database | `ivig` |
| User | `ivig` |
| Password | `Passw0rd!` |

### LDAP

| Parameter | Value |
|---|---|
| Host | `<SERVER_IP>` |
| Port | `30636` |
| Protocol | LDAPS |
| Base DN | `dc=ivig` |
| Bind DN | `cn=root` |
| Password | `Passw0rd!` |

The installer generates self-signed certificates. Import the root CA in your LDAP client if needed:

```bash
cat ~/ivig_starter_kit_11.0.2/config/certs/isvgimRootCA.crt
```

---

## Kubernetes

Namespace: `ivig` — storage class: `local-path`

| NodePort | Service |
|---|---|
| `30943` | IVIG Console (HTTPS) |
| `30543` | PostgreSQL |
| `30636` | LDAP / LDAPS |

```bash
# Pod status
kubectl -n ivig get pods

# Services
kubectl -n ivig get svc
```

---

## Container images

| Image | Tag |
|---|---|
| `icr.io/isvg/identity-manager` | `11.0.2.0` |
| `icr.io/isvdi/verify-directory-integrator-dispatcher` | `11.0.0.0` |
| `icr.io/isvd/verify-directory-server` | `11.0.0.0_IF1` |
| `icr.io/isvd/verify-directory-proxy` | `11.0.0.0_IF1` |
| `icr.io/isvd/verify-directory-seed` | `11.0.0.0_IF1` |
| `icr.io/isvg/mq` | `9.4.0.20` |
| `icr.io/isvg/kubegres` | `1.19` |
| `icr.io/isvg/ivig-ae` | `11.0.2.0` |
| `gcr.io/kubebuilder/kube-rbac-proxy` | `v0.16.0` |
| `postgres` | `15.14-bookworm` |

# hollowcrown

Hollowcrown was the name of the council that governed Ashfeld before it fell apart. When the council dissolved, the name passed to the bureau that kept its records — the registry of workers, departments, appointments and departures. It is the closest thing Ashfeld has to an official roster. Whether the data is accurate is a different question.

This project is a fictional HR system. It provides a REST API and a web UI for managing employees across departments, and serves as the upstream identity feed for integration exercises against the darkhorn backends.

---

## Architecture

```
+-----------------------------------------------+
|                  hollowcrown                  |
|                                               |
|  +-----------+     +-----------+     +-----+  |
|  |  Web UI   | --> |    API    | --> |  DB |  |
|  |  :8080    |     |  :4000    |     |  PG |  |
|  +-----------+     +-----------+     +-----+  |
+-----------------------------------------------+
```

| Service | Image | Port |
|---|---|---|
| `hollowcrown-web` | nginx (built from Vite) | `8080` |
| `hollowcrown-api` | node:18-alpine | `4000` (internal) |
| `hollowcrown-db` | postgres:15-alpine | internal only |

---

## Quick start

```bash
docker compose up --build -d
```

The web UI will be available at **http://localhost:8080** (or the host's IP on port 8080).

The seed container runs once on first boot and populates 50 employees across 6 departments; subsequent restarts skip the seed automatically.

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_DB` | `hollowcrown` | Database name |
| `POSTGRES_USER` | `crownkeeper` | PostgreSQL user |
| `POSTGRES_PASSWORD` | `C0r0n4Kpr!` | PostgreSQL password |
| `WEB_PORT` | `8080` | Host port for the web UI |

---

## API reference

No authentication required.

Base URL: `http://<host>:4000`

### Employees

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/employees` | List employees (supports `search`, `department`, `status`, `page`, `limit`) |
| `POST` | `/api/employees` | Create employee |
| `GET` | `/api/employees/:id` | Get employee by UUID |
| `PUT` | `/api/employees/:id` | Update employee |
| `POST` | `/api/employees/:id/terminate` | Terminate employee (`termination_date` required) |
| `POST` | `/api/employees/:id/set-status` | Change status (`active` / `on-leave`) |

### Departments

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/departments` | List all departments |

### Other

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/health` | Liveness check |
| `GET` | `/api/stats` | Dashboard stats (counts, by-department, recent hires) |

---

## Employee model

```json
{
  "id":               "uuid",
  "employee_id":      "HC-00042",
  "first_name":       "Jane",
  "last_name":        "Doe",
  "email":            "jane.doe@hollowcrown.local",
  "phone":            "+1-555-8271",
  "department":       "Engineering",
  "job_title":        "Senior Engineer",
  "manager_id":       "uuid | null",
  "hire_date":        "2019-03-15",
  "status":           "active | on-leave | terminated",
  "termination_date": "2024-01-01 | null",
  "created_at":       "ISO 8601",
  "updated_at":       "ISO 8601"
}
```

### Status lifecycle

```
active --> on-leave --> active
active --> terminated
on-leave --> terminated
```

> **Note:** Terminated employees are never deleted — their records remain for historical reference.

---

## Integration scenarios

hollowcrown is the **source of truth** for employee identity. The connector reads from hollowcrown and keeps accounts on the darkhorn backends in sync with it.

| JLM event | hollowcrown | IAM action |
|---|---|---|
| **Joiner** | Employee is `active`, no account exists | Provision |
| **Leaver** | Employee is `terminated` | Deprovision |
| **Mover** | Employee is `on-leave` | Suspend (policy-dependent) |
| **Mover** | Employee attributes changed (name, email, department, title) | Modify |

A full reconciliation cycle: read all hollowcrown employees → compare against target accounts → apply delta.

---

## Resetting to initial state

Use these procedures depending on how much you want to roll back.

### Wipe all employee data and re-seed

Drops the database volume and re-creates it from scratch. All changes made through the UI or API are lost. The stack restarts with the original 50 employees.

```bash
docker compose down -v
docker compose up -d
```

The seed runs automatically on first boot and repopulates the data.


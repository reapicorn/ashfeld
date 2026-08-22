# hollowcrown

Hollowcrown was the name of the council that governed Ashfeld before it fell apart. When the council dissolved, the name passed to the bureau that kept its records — the registry of workers, departments, appointments and departures. It is the closest thing Ashfeld has to an official roster. Whether the data is accurate is a different question.

This project is a fictional HR system. It provides a REST API and a web UI for managing employees across departments, and serves as the upstream identity feed for integration exercises against the darkhorn backends.

---

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

| JLM event | Business event | IAM action |
|---|---|---|
| **Joiner** | New hire | Provision |
| **Leaver** | Resignation or termination | Deprovision |
| **Mover** | Leave of absence | Suspend (policy-dependent) |
| **Mover** | Role, department or attribute change | Modify |

A full reconciliation cycle: read all hollowcrown employees → compare against target accounts → apply delta.

---

## Resetting to initial state

Drops the database volume and re-seeds from scratch. All changes made through the UI or API are lost.

```bash
docker compose down -v
docker compose up -d
```

The seed runs automatically on first boot and repopulates the data.


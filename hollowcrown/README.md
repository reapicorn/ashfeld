# hollowcrown

Hollowcrown was the name of the council that governed Ashfeld before it fell apart. When the council dissolved, the name passed to the bureau that kept its records — the registry of workers, departments, appointments and departures. It is the source of truth for identity in the city. The web UI gives humans a way to manage that record. The API gives systems a way to read it.

---

## Integration scenarios

What the Bureau records, the backends are expected to mirror. A new citizen joining the city means a new entry in the system. A termination means the opposite.

| JLM event | Business event | IAM action |
|---|---|---|
| **Joiner** | New hire | Provision |
| **Leaver** | Resignation or termination | Deprovision |
| **Mover** | Leave of absence | Suspend (policy-dependent) |
| **Mover** | Role, department or attribute change | Modify |

---

## Employee model

Every citizen who was ever part of the city has an entry. The fields are standard. Whether they were filled in correctly is another matter.

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

Three states. The city has a word for the third one but the Bureau just calls it terminated.

```
active --> on-leave --> active
active --> terminated
on-leave --> terminated
```

> **Note:** Terminated citizens are never deleted. Hollowcrown was a record office before it was anything else — removing a name from the roster was considered worse than keeping a wrong one.

---

## API reference

> The Bureau doesn't ask who's reading. Anyone with the address can pull the roster.

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

### System

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/health` | Liveness check |
| `GET` | `/api/stats` | Dashboard stats (counts, by-department, recent hires) |

---

## Vagrant

### Start

```bash
cd hollowcrown
vagrant up
```

### Access

| Service | URL |
|---|---|
| Web UI | `http://10.10.10.30:8080` |
| API | `http://10.10.10.30:4000` |

### Day-to-day

```bash
# Stop
vagrant halt

# Start
vagrant up

# Shell into the VM
vagrant ssh

# Container status
vagrant ssh -c "docker ps"

# Logs
vagrant ssh -c "docker compose -f /vagrant/docker-compose.yml logs -f"

# Destroy and start fresh
vagrant destroy -f && vagrant up
```

### Machine requirements

| Resource | Value |
|---|---|
| CPU | 1 vCPU |
| RAM | 1 GB |
| Disk | 15 GB |


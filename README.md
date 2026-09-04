# ashfeld

Ashfeld is a decaying industrial city, once known for its foundries and its archives. Today it is a city in transition — its old guilds dissolved, its districts repurposed, its remaining organizations held together by paperwork and habit. Nobody agrees on who is in charge. Nobody agrees on who still works here.

This lab puts you in the city and gives you the keys. The backends are real, the protocols are live, and the data is already there waiting. You are not reading about identity provisioning — you are doing it, against systems that behave the way systems behave in the real world: inconsistently, on their own terms, without a common standard in sight.

```
.
├── darkhorn/        # the district — six companies, six ways of keeping the same records
├── hollowcrown/     # HR source system — the identity source of truth
├── Ironhold/        # PAM vault — privileged credentials, checkout, rotation
└── Thorngate/       # Identity governance — lifecycle, roles, provisioning policies
```

---

## Projects

### darkhorn

Six companies settled in the Darkhorn district after the foundries closed. None of them inherited the same systems. None of them agreed to standardize. They each handle the same three questions — who works here, what do they have access to, are they still active — and they each answer in a different language.

→ See [`darkhorn/README.md`](darkhorn/README.md) — the six companies, their doors, and what moves across the wire.

### hollowcrown

The HR system. Every identity in Ashfeld starts here — hired, transferred, terminated. Hollowcrown is the source of truth that the rest of the city is supposed to reflect.

→ See [`hollowcrown/README.md`](hollowcrown/README.md)

### Ironhold

The vault. Privileged credentials, service accounts, infrastructure secrets. If something has a password that matters, Ironhold is where it lives.

→ See [`Ironhold/README.md`](Ironhold/README.md)

### Thorngate

The gate. Lifecycle management, role governance, provisioning policies. Thorngate decides who gets access, to what, and under what conditions.

→ See [`Thorngate/README.md`](Thorngate/README.md)

---

## Prerequisites

Vagrant and a VMware hypervisor are required for all components.

**Install VMware:** [vmware.com/products/desktop-hypervisor](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion)

| Machine | Hypervisor |
|---|---|
| Windows | VMware Workstation Pro |
| Mac Intel | VMware Fusion |
| Mac Apple Silicon (M1/M2/M3) | VMware Fusion 13+ |
| Linux | VMware Workstation |

**Install Vagrant:** [developer.hashicorp.com/vagrant/downloads](https://developer.hashicorp.com/vagrant/downloads)

**Install the Vagrant VMware plugin (one-time):**

```bash
vagrant plugin install vagrant-vmware-desktop
```

**Install the VMware Utility Service:** [developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility](https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility)

---

## Clone

```bash
git clone https://github.com/reapicorn/ashfeld ~/ashfeld
```

---

## darkhorn + hollowcrown

Both run on Docker in a Debian 12 VM. Each has its own `Vagrantfile`.

### Start

```bash
# darkhorn
cd ~/ashfeld/darkhorn && vagrant up

# hollowcrown
cd ~/ashfeld/hollowcrown && vagrant up
```

### Access

| Component | URL |
|---|---|
| darkhorn REST | `http://10.10.10.20:3000` |
| darkhorn SOAP | `http://10.10.10.20:3002` |
| darkhorn JDBC | `10.10.10.20:5432` |
| darkhorn LDAP | `10.10.10.20:389` |
| darkhorn SFTP | `10.10.10.20:2222` |
| darkhorn MQ (AMQP) | `10.10.10.20:5672` |
| RabbitMQ mgmt | `http://10.10.10.20:15672` |
| hollowcrown Web UI | `http://10.10.10.30:8080` |
| hollowcrown API | `http://10.10.10.30:4000` |

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

### darkhorn machine requirements

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Disk | 15 GB | 20 GB |

---

## Ironhold

Windows Server 2025 VM.

### Before starting

The installer is not included. Obtain it separately and place it in `Ironhold/installer/` (any filename, `.exe` or `.zip`).

### Start

```bash
cd Ironhold
vagrant up
```

Vagrant downloads a Windows Server 2025 VM (~7 GB, first time only), installs SQL Server Express, and provisions the vault. First run: ~15 minutes. Subsequent starts: ~2 minutes.

### Access

| | |
|---|---|
| URL | `http://10.10.10.10/SecretServer` |
| Username | `admin` |
| Password | `Passw0rd!` |
| RDP | `10.10.10.10:3389` — `vagrant` / `vagrant` |

### Day-to-day

```bash
# Stop
vagrant halt

# Start
vagrant up

# RDP into the VM
vagrant rdp
# Credentials: vagrant / vagrant

# Re-run provisioning (if it failed mid-way)
vagrant provision

# Destroy and start fresh
vagrant destroy -f && vagrant up
```

### Machine requirements

| Resource | Value |
|---|---|
| CPU | 2 vCPU |
| RAM | 4 GB |
| Disk | 25 GB |

---

## Thorngate

Ubuntu Server 24.04 VM running an identity governance stack on k3s.

### Before starting

The installer kit and license keys are not included. Obtain them separately and place them in `Thorngate/` before running `vagrant up`.

### Start

```bash
cd Thorngate
vagrant up
```

### Access

| | |
|---|---|
| Console | `https://10.10.10.40:30943/itim/console` |
| Username | `itim manager` |
| Password | `secret` |
| Tenant | `Acme` |

### Day-to-day

```bash
# Stop
vagrant halt

# Start
vagrant up

# Shell into the VM
vagrant ssh

# Pod status
vagrant ssh -c "kubectl -n ivig get pods"

# Services
vagrant ssh -c "kubectl -n ivig get svc"

# Full uninstall / reset
vagrant ssh -c "cd ~/ivig_starter_kit_11.0.2/bin && ./sys/cleanup.sh -force"

# Destroy and start fresh
vagrant destroy -f && vagrant up
```

### Machine requirements

| Resource | Value |
|---|---|
| CPU | 4 vCPUs |
| RAM | 16 GB |
| Disk | 100 GB |
| OS | Ubuntu Server 24.04 LTS (x86_64) |

> ARM is not supported directly. Container images are `amd64`-only.

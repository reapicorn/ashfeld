# Stonewrit

In Ashfeld, when a norm reached Stonewrit it meant there was nothing left to discuss. Not every decision passed through there — only the ones the council considered permanent. The ones that defined what a citizen was entitled to from the first day they set foot in the city. The conditions under which access could be granted without appeal, and the conditions under which it could be revoked without one.

The name is not a metaphor. The building had an engraving room. Norms were inscribed physically into limestone slabs mounted on the walls. The idea was that what was permanent should not depend on someone keeping the paper.

The building is still standing. The slabs are still there. Some of the norms carved into those walls have not been reviewed in decades — because in Stonewrit, correcting a norm means first admitting the previous version was wrong, and that carries a political cost nobody has been willing to pay.

That cost is now due. The inscriptions define birthright access for roles that no longer exist, restrictions between systems that were replaced, and revocation conditions that in several cases were never enforced. Hollowcrown has the roster. Darkhorn has the systems. Stonewrit has the law — and someone has to read the walls, decide what is still binding, and carve the corrections.

---

## Vagrant

### Before starting

The installer kit and license keys are not included. Obtain them separately and place them in the appropriate folders before running `vagrant up`:

```
stonewrit/
├── starter_kit/
│   └── ivig_starter_kit_11.0.2/   ← starter kit folder from IBM
└── license_files/
    ├── ivig_activation_key_11.0.2.txt
    ├── ivig_Enterprise_CT_key_11.0.2.txt
    ├── ivd-11.0.0_license_key_limited.txt
    └── SVDI_11.0_Con_Lic_Key_ML.txt
```

### Start

```bash
vagrant up
```

### Access

| | |
|---|---|
| Console | `https://localhost:30943/itim/console/main` |
| Username | `itim manager` |
| Password | `secret` |

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

**Intel / AMD (x86_64)**

| Resource | Value |
|---|---|
| CPU | 4 vCPUs |
| RAM | 12 GB |
| Disk | Default box disk (64 GiB virtual capacity) |
| OS | Debian 12 (x86_64) |
| Provider | VMware Fusion / Workstation |

**Apple Silicon (ARM64, experimental — not validated)**

| Resource | Value |
|---|---|
| CPU | 4 vCPUs |
| RAM | 12 GB |
| Disk | Default box disk (capacity depends on the ARM box version) |
| OS | Debian 12 (arm64) |
| Provider | VMware Fusion 13.5+ |
| macOS | 13 Ventura or later |

The box `bento/debian-12` supports both `amd64` and `arm64` under `vmware_desktop`. On ARM hosts, k3s runs natively on ARM64. IVIG images are amd64-only, so their execution relies on VMware Fusion's Rosetta translation support being available in the guest environment. This configuration has not been validated on Apple Silicon and is not a supported deployment path.

Run `vagrant up` and verify that all `ivig` pods are Ready and that the console is reachable before using the lab.

---

## External connections

### PostgreSQL

| Parameter | Value |
|---|---|
| Host | `localhost` |
| Port | `30543` |
| Database | `ivig` |
| User | `ivig` |
| Password | `Thr0ng4t3DB!` |

### LDAP

| Parameter | Value |
|---|---|
| Host | `localhost` |
| Port | `30636` |
| Protocol | LDAPS |
| Base DN | `dc=ivig` |
| Bind DN | `cn=root` |
| Password | `Thr0ng4t3LD!` |

The installer generates self-signed certificates. Import the root CA in your LDAP client if needed:

```bash
vagrant ssh -c "cat ~/ivig_starter_kit_11.0.2/config/certs/isvgimRootCA.crt"
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

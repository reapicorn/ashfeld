# Installing IVIG 11.0.2 with k3s on Ubuntu Server

## System Requirements

| Resource | Minimum |
|---|---|
| CPU | 4 vCPUs |
| RAM | 16 GB |
| Disk | 100 GB |
| OS | Ubuntu Server 24.04 LTS (or latest) |
| Architecture | x86_64 (amd64) only — **ARM is not supported** |

> **On ARM hardware (Apple Silicon, Raspberry Pi, etc.):** check your architecture before creating the VM. See [Running on ARM hardware](#running-on-arm-hardware).

---

## Running on ARM hardware

IVIG images are `amd64`-only. If your host is ARM, you need to emulate an x86_64 VM before proceeding.

Check your architecture:

**macOS / Linux:**
```bash
uname -m
# arm64 or aarch64 = ARM
```

**Windows:**
```powershell
(Get-CimInstance Win32_OperatingSystem).OSArchitecture
# ARM 64-bit = ARM
```

If your host is x86_64, skip this section entirely.

### macOS Apple Silicon — UTM (free)

> ⚠️ Networking behavior may vary. Not fully validated across all environments.

1. Download and install [UTM](https://mac.getutm.app/)
2. In UTM, create a new VM:
   - Virtualization: **Emulate**, Architecture: **x86_64**
   - RAM: 16 GB, CPU: 4 cores, Disk: 100 GB
   - Network: **Shared Network**
3. Boot from the ISO and complete the Ubuntu install

> Emulation is slower than native. Expect longer install times.

### Linux ARM — KVM/QEMU (free)

> ⚠️ Networking behavior may vary. Not fully validated across all environments.

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst
sudo usermod -aG libvirt $(whoami)
newgrp libvirt
```

```bash
# Create a 100GB disk image
qemu-img create -f qcow2 ivig-ubuntu.qcow2 100G

# Install Ubuntu from ISO (runs headless, emulating x86_64)
virt-install \
  --name ivig-ubuntu \
  --ram 16384 \
  --vcpus 4 \
  --arch x86_64 \
  --disk path=ivig-ubuntu.qcow2,format=qcow2 \
  --cdrom ubuntu-24.04-live-server-amd64.iso \
  --os-variant ubuntu24.04 \
  --network bridge=br0 \
  --graphics none \
  --console pty,target_type=serial

# Connect to the VM console later
virsh console ivig-ubuntu
```

### Validate VM networking

Once Ubuntu is installed and running, verify the VM has a reachable IP:

```bash
# On the VM — check the assigned IP
ip addr show | grep 'inet '

# From the host — verify connectivity
ping <VM_IP>

# From the host — verify IVIG port is reachable (after installation)
curl -k https://<VM_IP>:30943/itim/console
```

---

## 1. Prepare the OS

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git tar unzip jq
```

---

## 2. Install k3s

```bash
curl -sfL https://get.k3s.io | sh -
```

Configure `kubectl` for the current user:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

---

## 3. Install Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 4. Pre-load Container Images (no internet on the VM)

> Skip this section if the VM has direct internet access and can reach `icr.io`.

If the VM has no internet connectivity, pull all images on your local machine (which does have internet), save them as a tar file, copy it to the VM, and import them into k3s.

Requires [Podman](https://podman.io/) installed on your local machine. Podman is free, lightweight, and requires no daemon or WSL2.

**macOS:**
```bash
brew install podman
podman machine init && podman machine start
```

**Windows:**
```powershell
winget install RedHat.Podman
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt install -y podman
```

**1. Log in to the IBM Container Registry — on your local machine:**

```bash
podman login icr.io -u iamapikey -p <YOUR_IBM_CLOUD_API_KEY>
```

**2. Pull all images — on your local machine:**

```bash
podman pull icr.io/isvg/identity-manager:11.0.2.0
podman pull icr.io/isvdi/verify-directory-integrator-dispatcher:11.0.0.0
podman pull icr.io/isvd/verify-directory-server:11.0.0.0_IF1
podman pull icr.io/isvd/verify-directory-proxy:11.0.0.0_IF1
podman pull icr.io/isvd/verify-directory-seed:11.0.0.0_IF1
podman pull icr.io/isvg/mq:9.4.0.20
podman pull icr.io/isvg/kubegres:1.19
podman pull icr.io/isvg/ivig-ae:11.0.2.0
podman pull gcr.io/kubebuilder/kube-rbac-proxy:v0.16.0
podman pull postgres:15.14-bookworm
```

**3. Save all images into a single tar archive — on your local machine:**

```bash
podman save --multi-image-archive \
  icr.io/isvg/identity-manager:11.0.2.0 \
  icr.io/isvdi/verify-directory-integrator-dispatcher:11.0.0.0 \
  icr.io/isvd/verify-directory-server:11.0.0.0_IF1 \
  icr.io/isvd/verify-directory-proxy:11.0.0.0_IF1 \
  icr.io/isvd/verify-directory-seed:11.0.0.0_IF1 \
  icr.io/isvg/mq:9.4.0.20 \
  icr.io/isvg/kubegres:1.19 \
  icr.io/isvg/ivig-ae:11.0.2.0 \
  gcr.io/kubebuilder/kube-rbac-proxy:v0.16.0 \
  postgres:15.14-bookworm \
  -o ivig-images.tar
```

> The tar file will be approximately 10–15 GB.

**4. Copy the tar to the VM:**

```bash
scp ivig-images.tar user@<SERVER_IP>:~/
```

**5. Import images into k3s — on the VM:**

k3s uses `containerd`, not Docker. Use `k3s ctr` to import:

```bash
sudo k3s ctr images import ~/ivig-images.tar
```

This may take a few minutes. Verify all images are loaded:

```bash
sudo k3s ctr images list | grep -E 'icr\.io|gcr\.io|postgres'
```

You should see all 10 images listed. Once confirmed, proceed to the next step — the installer will use the locally cached images and will not attempt to pull from the internet.

---

## 5. Copy Files to the Server

From your local machine:

```bash
scp -r ./ivig_starter_kit_11.0.2 \
    ./ivig_activation_key_11.0.2.txt \
    ./ivig_Enterprise_CT_key_11.0.2.txt \
    ./ivd-11.0.0_license_key_limited.txt \
    ./SVDI_11.0_Con_Lic_Key_ML.txt \
    user@<SERVER_IP>:~/
```

Then on the server:

```bash
chmod -R +x ~/ivig_starter_kit_11.0.2/bin/
```

---

## 6. Configure `config.yaml`

Run the following commands to set all required values. The license key commands read the values directly from the files copied in step 5.

**Fixed values (passwords, storageclass, DB, LDAP):**

```bash
CFG=~/ivig_starter_kit_11.0.2/config/config.yaml

# storageclass
sed -i 's/^    storageclass:$/    storageclass: local-path/' "$CFG"

# accepted license
sed -i 's/^    accepted:$/    accepted: true/' "$CFG"

# server keystore password
sed -i 's/^  keypass:$/  keypass: Passw0rd!/' "$CFG"

# database
sed -i 's/^  user:$/  user: ivig/' "$CFG"
sed -i 's/^  password:$/  password: Passw0rd!/' "$CFG"
sed -i 's/^  ip:$/  ip: postgres/' "$CFG"
sed -i 's/^  port:$/  port: 5432/' "$CFG"

# ldap
sed -i 's/^  security\.principal:$/  security.principal: cn=root/' "$CFG"
sed -i 's/^  security\.credentials:$/  security.credentials: Passw0rd!/' "$CFG"
sed -i 's/^  defaulttenant\.id:$/  defaulttenant.id: Acme/' "$CFG"
sed -i 's/^  organization\.name:$/  organization.name: Acme Inc./' "$CFG"
sed -i 's/^  ldapserver\.ip:$/  ldapserver.ip: isvd-replica-1/' "$CFG"
sed -i 's/^  ldapserver\.port:$/  ldapserver.port: 9636/' "$CFG"
```

**License keys (read from files):**

```bash
CFG=~/ivig_starter_kit_11.0.2/config/config.yaml

ACTIVATION_KEY=$(grep -v '^#' ~/ivig_activation_key_11.0.2.txt | tr -d '[:space:]')
LDAP_KEY=$(grep -v '^#' ~/ivd-11.0.0_license_key_limited.txt | tr -d '[:space:]')
ISVDI_KEY=$(grep -v '^#' ~/SVDI_11.0_Con_Lic_Key_ML.txt | tr -d '[:space:]')
ISVART_KEY=$(grep -v '^#' ~/ivig_Enterprise_CT_key_11.0.2.txt | tr -d '[:space:]')

sed -i "s/^    activationKey:$/    activationKey: $ACTIVATION_KEY/" "$CFG"
sed -i "s/^    ldapKey:$/    ldapKey: $LDAP_KEY/" "$CFG"
sed -i "s/^    isvdiKey:$/    isvdiKey: $ISVDI_KEY/" "$CFG"
sed -i "s/^    isvartKey:$/    isvartKey: $ISVART_KEY/" "$CFG"
```

**Verify the result:**

```bash
CFG=~/ivig_starter_kit_11.0.2/config/config.yaml
OK=true

check() {
  local label="$1"
  local pattern="$2"
  if grep -qE "$pattern" "$CFG"; then
    echo "  [OK] $label"
  else
    echo "  [MISSING] $label"
    OK=false
  fi
}

check "storageclass"           'storageclass: local-path'
check "license accepted"       'accepted: true'
check "server keypass"         'keypass: .+'
check "db user"                'user: ivig'
check "db password"            'password: .+'
check "db ip"                  'ip: postgres'
check "db port"                'port: 5432'
check "ldap principal"         'security\.principal: .+'
check "ldap credentials"       'security\.credentials: .+'
check "ldap defaulttenant"     'defaulttenant\.id: .+'
check "ldap organization"      'organization\.name: .+'
check "ldap server ip"         'ldapserver\.ip: .+'
check "ldap server port"       'ldapserver\.port: .+'
check "activationKey"          'activationKey: .+'
check "ldapKey"                'ldapKey: .+'
check "isvdiKey"               'isvdiKey: .+'
check "isvartKey"              'isvartKey: .+'

if $OK; then
  echo ""
  echo "All fields set. Ready to run the installer."
else
  echo ""
  echo "Fix the missing fields above before proceeding."
fi
```

---

## 7. Run the Installer

```bash
cd ~/ivig_starter_kit_11.0.2/bin
./install.sh
```

When complete:

```
Installation complete!
You can now login at https://<IP>:30943/itim/console
```

---

## 8. Verify

```bash
kubectl -n ivig get pods
kubectl -n ivig get svc
```

| Service | NodePort | Description |
|---|---|---|
| isvgim | 30943 | IVIG Console (HTTPS) |
| postgres-external | 30543 | PostgreSQL |
| isvd-external | 30636 | LDAP (LDAPS) |

Login at `https://<SERVER_IP>:30943/itim/console`

- **Username:** `itim manager`
- **Password:** `secret`

---

## Appendix: External Access to PostgreSQL and LDAP

### Open firewall ports

```bash
sudo ufw allow 22/tcp
sudo ufw allow 30943/tcp
sudo ufw allow 30543/tcp
sudo ufw allow 30636/tcp
```

### PostgreSQL connection

| Parameter | Value |
|---|---|
| Host | `<SERVER_IP>` |
| Port | `30543` |
| Database | `ivig` |
| User | `db.user` |
| Password | `db.password` |

### LDAP connection

| Parameter | Value |
|---|---|
| Host | `<SERVER_IP>` |
| Port | `30636` |
| Protocol | LDAPS |
| Base DN | `dc=ivig` |
| Bind DN | `ldap.security.principal` |
| Password | `ldap.security.credentials` |

The installer generates self-signed certificates. Import `config/certs/isvgimRootCA.crt` as a trusted CA in your LDAP client.

```bash
cat ~/ivig_starter_kit_11.0.2/config/certs/isvgimRootCA.crt
```


---

## Cleanup / Uninstall

### Installation failed mid-way

If the installer fails, run cleanup before retrying:

```bash
cd ~/ivig_starter_kit_11.0.2/bin
./sys/cleanup.sh
```

This removes all Kubernetes objects deployed so far, clears generated files, and restores `config.yaml` to its original state. Safe to run on a partially installed system.

### Full uninstall (remove everything)

To completely remove IVIG from a running system:

```bash
cd ~/ivig_starter_kit_11.0.2/bin
./sys/cleanup.sh -force
```

> **Warning:** This deletes all data, including the database and LDAP contents. It cannot be undone.

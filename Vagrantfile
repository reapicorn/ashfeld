Vagrant.configure("2") do |config|

  config.vm.box = "bento/debian-12"
  config.vm.hostname = "darkhorn"

  # ── Network — bridged (DHCP) ──────────────────────────────────────────────────
  # VM gets its own IP from the local network router.
  # IP is printed at the end of vagrant up.
  config.vm.network "public_network"

  # ── VMware ────────────────────────────────────────────────────────────────────
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.vmx["memsize"]  = "2048"
    vmware.vmx["numvcpus"] = "2"
    vmware.gui = false
  end

  # ── VirtualBox (fallback) ─────────────────────────────────────────────────────
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 2048
    vb.cpus   = 2
    vb.gui    = false
  end

  # ── Provisioning ──────────────────────────────────────────────────────────────
  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail

    # Docker
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl git
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
      https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Allow vagrant user to run docker without sudo
    usermod -aG docker vagrant

    # Clone and start darkhorn
    sudo -u vagrant bash -c '
      git clone -q https://github.com/reapicorn/ashfeld ~/ashfeld
      bash ~/ashfeld/bin/ashfeld-setenv.sh
      docker compose -f ~/ashfeld/darkhorn/docker-compose.yml up --build -d
    '

    # Print VM IP
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    echo ""
    echo "======================================================"
    echo "  Darkhorn — Ready"
    echo "======================================================"
    echo "  REST:          http://$IP:3000"
    echo "  SOAP:          http://$IP:3002"
    echo "  JDBC:          $IP:5432"
    echo "  LDAP:          $IP:389"
    echo "  SFTP:          $IP:2222"
    echo "  MQ (AMQP):     $IP:5672"
    echo "  RabbitMQ mgmt: http://$IP:15672"
    echo "======================================================"
    echo ""
  SHELL

end

#!/bin/bash
# =============================================================
#  Stonewrit - Installation Script
#  IBM Verify Identity Governance (IVIG) on SLES 15 (Linux native)
#
#  Runs automatically via Vagrant on "vagrant up".
#  Safe to re-run individual steps manually from inside the VM.
#
#  Usage:
#    /vagrant/scripts/install.sh                        # run all steps
#    /vagrant/scripts/install.sh base,postgres          # run specific steps
#
#  Install steps:
#    base        Install system packages (Java, curl, unzip, etc.)
#    postgres    Install and configure PostgreSQL
#    isvd        Install IBM Security Verify Directory (LDAP server)
#    mq          Install IBM MQ and create queue manager
#    ivig        Install IBM Verify Identity Governance (Liberty)
#    service     Register IVIG as a systemd service and start it
#    wait        Wait for IVIG console to become available
# =============================================================

set -euo pipefail

# -- Configuration ---------------------------------------------
IVIG_HOME="/opt/IBM/ivig"
IDS_HOME="/opt/IBM/ldap/V11.0"
SVDI_HOME="/opt/IBM/svdi"
LAB_DIR="/opt/stonewrit"
LOG_FILE="${LAB_DIR}/install.log"

PG_DB="ivig"
PG_USER="ivig"
PG_PASS="St0n3writ#DB!"

LDAP_SUFFIX="dc=ivig"
LDAP_ADMIN_DN="cn=root,dc=ivig"
LDAP_ADMIN_PASS="St0n3writ#LD!"
LDAP_PORT=389
LDAPS_PORT=636

MQ_QMGR="ISVGQMgr"

IVIG_ADMIN_PASS="secret"
IVIG_TENANT="default"
IVIG_ORG="Stonewrit"

INSTALLER_DIR="/vagrant/installer"

# -- Step resolution -------------------------------------------
STEPS="${1:-}"
run_all=false
[ -z "${STEPS}" ] && run_all=true

should_run() {
    local name="$1"
    $run_all && return 0
    echo ",${STEPS}," | grep -q ",${name}," && return 0
    return 1
}

# -- Logging ---------------------------------------------------
mkdir -p "${LAB_DIR}"
log()  { local ts; ts=$(date +"%H:%M:%S"); echo "${ts}  $*" | tee -a "${LOG_FILE}"; }
step() { log ""; log "==> $*"; }

# -- Banner ----------------------------------------------------
step "Starting Stonewrit installation"
if $run_all; then log "Running steps: all"
else              log "Running steps: ${STEPS}"
fi

# ==============================================================
# STEP: base
# ==============================================================
if should_run "base"; then
    step "[base] Installing system packages..."

    zypper --non-interactive refresh
    zypper --non-interactive install -y \
        curl wget unzip tar gzip \
        python3 \
        hostname net-tools \
        java-11-openjdk \
        libstdc++6 \
        libgcc_s1 \
        pam \
        libaio1 \
        libpam-modules 2>/dev/null || \
    zypper --non-interactive install -y \
        curl wget unzip tar gzip \
        python3 \
        hostname net-tools \
        java-11-openjdk \
        libstdc++6 \
        libgcc_s1

    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java) 2>/dev/null)) 2>/dev/null) || true
    echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment || true

    log "[base] Done."
fi

# ==============================================================
# STEP: postgres
# ==============================================================
if should_run "postgres"; then
    step "[postgres] Installing and configuring PostgreSQL..."

    zypper --non-interactive install -y postgresql-server postgresql

    systemctl enable postgresql
    systemctl start postgresql

    # Create user and database (idempotent)
    sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${PG_USER}'" \
        | grep -q 1 || \
        sudo -u postgres psql -c "CREATE USER ${PG_USER} WITH PASSWORD '${PG_PASS}';"

    sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${PG_DB}'" \
        | grep -q 1 || \
        sudo -u postgres psql -c "CREATE DATABASE ${PG_DB} OWNER ${PG_USER};"

    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${PG_DB} TO ${PG_USER};"

    # Allow password auth from localhost
    PG_HBA=$(sudo -u postgres psql -t -c "SHOW hba_file;" | tr -d '[:space:]')
    if ! grep -q "host.*${PG_DB}.*${PG_USER}" "${PG_HBA}" 2>/dev/null; then
        echo "host    ${PG_DB}    ${PG_USER}    127.0.0.1/32    md5" >> "${PG_HBA}"
        echo "host    ${PG_DB}    ${PG_USER}    ::1/128         md5" >> "${PG_HBA}"
        systemctl reload postgresql
    fi

    log "[postgres] Done. DB=${PG_DB}, user=${PG_USER}"
fi

# ==============================================================
# STEP: isvd
# ==============================================================
if should_run "isvd"; then
    step "[isvd] Installing IBM Security Verify Directory..."

    IVD_DIR=$(ls -d "${INSTALLER_DIR}"/ivd-* 2>/dev/null | head -1)
    if [ -z "${IVD_DIR}" ]; then
        log "ERROR: ISVD installer directory not found in ${INSTALLER_DIR}"
        exit 1
    fi

    # Install GSKit (SSL toolkit required by ISVD)
    if [ -x "${IVD_DIR}/gskinstall" ]; then
        log "[isvd] Installing GSKit..."
        "${IVD_DIR}/gskinstall" -i 2>>"${LOG_FILE}" || true
    fi

    # Install ISVD RPMs
    log "[isvd] Installing RPMs..."
    rpm --install --nodeps \
        "${IVD_DIR}/images/idsldap-license"*".rpm" \
        "${IVD_DIR}/images/idsldap-cltbase"*".rpm" \
        "${IVD_DIR}/images/idsldap-clt64bit"*".rpm" \
        "${IVD_DIR}/images/idsldap-cltjava"*".rpm" \
        "${IVD_DIR}/images/idsldap-srvbase64bit"*".rpm" \
        "${IVD_DIR}/images/idsldap-srv64bit"*".rpm" 2>>"${LOG_FILE}" || \
    rpm --upgrade --nodeps \
        "${IVD_DIR}/images/idsldap-license"*".rpm" \
        "${IVD_DIR}/images/idsldap-cltbase"*".rpm" \
        "${IVD_DIR}/images/idsldap-clt64bit"*".rpm" \
        "${IVD_DIR}/images/idsldap-cltjava"*".rpm" \
        "${IVD_DIR}/images/idsldap-srvbase64bit"*".rpm" \
        "${IVD_DIR}/images/idsldap-srv64bit"*".rpm" 2>>"${LOG_FILE}"

    # Create idsldap OS user (required by ISVD instance)
    id idsldap &>/dev/null || \
        "${IDS_HOME}/sbin/idsadduser" -u idsldap -g idsldap -l /home/idsldap 2>>"${LOG_FILE}" || \
        useradd -m -d /home/idsldap idsldap

    # Create LDAP instance named "ivig"
    if ! "${IDS_HOME}/sbin/idsListInstance" -I ivig &>/dev/null 2>&1; then
        log "[isvd] Creating LDAP instance..."
        sudo -u idsldap "${IDS_HOME}/sbin/idsicrt" -I ivig \
            -p "${LDAP_PORT}" \
            -s "${LDAPS_PORT}" \
            -e 2>>"${LOG_FILE}" || true

        sudo -u idsldap "${IDS_HOME}/sbin/idscfgdb" -I ivig \
            -a idsldap \
            -w idsldap \
            -t ivig \
            -l /home/idsldap 2>>"${LOG_FILE}" || true

        sudo -u idsldap "${IDS_HOME}/sbin/idscfgsuf" -I ivig \
            -s "${LDAP_SUFFIX}" 2>>"${LOG_FILE}" || true

        # Set admin DN and password
        sudo -u idsldap "${IDS_HOME}/sbin/idsdnpw" -I ivig \
            -u "${LDAP_ADMIN_DN}" \
            -p "${LDAP_ADMIN_PASS}" 2>>"${LOG_FILE}" || true
    else
        log "[isvd] LDAP instance 'ivig' already exists."
    fi

    # Start LDAP server
    sudo -u idsldap "${IDS_HOME}/sbin/ibmslapd" -I ivig -n 2>>"${LOG_FILE}" || true

    # Wait for LDAP to be ready
    log "[isvd] Waiting for LDAP on port ${LDAP_PORT}..."
    for i in $(seq 1 30); do
        nc -z localhost "${LDAP_PORT}" 2>/dev/null && break || true
        sleep 2
    done

    log "[isvd] Done. LDAP suffix=${LDAP_SUFFIX}, port=${LDAP_PORT}"
fi

# ==============================================================
# STEP: mq
# ==============================================================
if should_run "mq"; then
    step "[mq] Installing IBM MQ..."

    MQ_TAR=$(ls "${INSTALLER_DIR}"/*-IBM-MQ-LinuxX64.tar.gz 2>/dev/null | head -1)
    if [ -z "${MQ_TAR}" ]; then
        log "ERROR: IBM MQ tarball not found in ${INSTALLER_DIR}"
        exit 1
    fi

    MQ_TMP="/tmp/mq_install"
    rm -rf "${MQ_TMP}"
    mkdir -p "${MQ_TMP}"
    tar -xzf "${MQ_TAR}" -C "${MQ_TMP}" --strip-components=1

    cd "${MQ_TMP}"
    ./mqlicense.sh -text_only -accept 2>>"${LOG_FILE}"
    rpm --install --nodeps \
        MQSeriesRuntime-*.rpm \
        MQSeriesServer-*.rpm \
        MQSeriesJava-*.rpm \
        MQSeriesJRE-*.rpm 2>>"${LOG_FILE}" || \
    rpm --upgrade --nodeps \
        MQSeriesRuntime-*.rpm \
        MQSeriesServer-*.rpm \
        MQSeriesJava-*.rpm \
        MQSeriesJRE-*.rpm 2>>"${LOG_FILE}"
    cd /

    # Add mqm user to vagrant group for shared folder access
    usermod -aG vagrant mqm 2>/dev/null || true

    # Create and start queue manager
    if ! /opt/mqm/bin/dspmq -m "${MQ_QMGR}" &>/dev/null 2>&1; then
        log "[mq] Creating queue manager ${MQ_QMGR}..."
        /opt/mqm/bin/crtmqm "${MQ_QMGR}" 2>>"${LOG_FILE}" || true
    fi
    /opt/mqm/bin/strmqm "${MQ_QMGR}" 2>>"${LOG_FILE}" || true

    # Apply IVIG MQ queues configuration
    MQSC_FILE=$(find "${INSTALLER_DIR}" -name "ISVGQMgr.mqsc" -path "*/mq/plain/*" 2>/dev/null | head -1)
    if [ -n "${MQSC_FILE}" ]; then
        log "[mq] Applying IVIG queue configuration..."
        /opt/mqm/bin/runmqsc "${MQ_QMGR}" < "${MQSC_FILE}" 2>>"${LOG_FILE}" || true
    fi

    log "[mq] Done. Queue manager=${MQ_QMGR}"
fi

# ==============================================================
# STEP: ivig
# ==============================================================
if should_run "ivig"; then
    step "[ivig] Installing IBM Verify Identity Governance..."

    IVIG_ZIP=$(ls "${INSTALLER_DIR}"/ivig_imsw_*.zip 2>/dev/null | head -1)
    if [ -z "${IVIG_ZIP}" ]; then
        log "ERROR: IVIG installer zip not found in ${INSTALLER_DIR}"
        exit 1
    fi

    # Extract if not already done
    if [ ! -d "${IVIG_HOME}/wlp" ]; then
        log "[ivig] Extracting ${IVIG_ZIP}..."
        mkdir -p "${IVIG_HOME}"
        unzip -q "${IVIG_ZIP}" -d "${IVIG_HOME}"
    else
        log "[ivig] IVIG already extracted at ${IVIG_HOME}."
    fi

    CFG_DATA="${IVIG_HOME}/wlp/usr/servers/defaultServer/config/data"
    CFG_SVR="${IVIG_HOME}/wlp/usr/servers/defaultServer/config/server"

    # Activate PostgreSQL datasource
    cp "${CFG_SVR}/datasource.xml.postgresql" "${CFG_SVR}/datasource.xml"

    # Activate MQ non-SSL config
    cp "${CFG_SVR}/IBMMQJmsConfig.xml.nonssl" "${CFG_SVR}/IBMMQJmsConfig.xml"

    # Configure enRoleDatabase.properties for PostgreSQL
    sed -i "s|^database.db.type=.*|database.db.type=POSTGRESQL|"       "${CFG_DATA}/enRoleDatabase.properties"
    sed -i "s|^database.db.owner=.*|database.db.owner=${PG_USER}|"     "${CFG_DATA}/enRoleDatabase.properties"
    sed -i "s|^database.db.user=.*|database.db.user=${PG_USER}|"       "${CFG_DATA}/enRoleDatabase.properties"
    sed -i "s|^database.db.password=.*|database.db.password=${PG_PASS}|" "${CFG_DATA}/enRoleDatabase.properties"
    sed -i "s|^database.jdbc.driverUrl=.*|database.jdbc.driverUrl=jdbc:postgresql://localhost:5432/${PG_DB}|" \
        "${CFG_DATA}/enRoleDatabase.properties"
    sed -i "s|^database.jdbc.driver=.*|database.jdbc.driver=org.postgresql.Driver|" \
        "${CFG_DATA}/enRoleDatabase.properties"

    # Configure LDAP connection
    sed -i "s|^java.naming.provider.url=.*|java.naming.provider.url=ldap://localhost:${LDAP_PORT}|" \
        "${CFG_DATA}/enRoleLDAPConnection.properties"
    sed -i "s|^java.naming.security.principal=.*|java.naming.security.principal=${LDAP_ADMIN_DN}|" \
        "${CFG_DATA}/enRoleLDAPConnection.properties"
    sed -i "s|^java.naming.security.credentials=.*|java.naming.security.credentials=${LDAP_ADMIN_PASS}|" \
        "${CFG_DATA}/enRoleLDAPConnection.properties"

    # Load enterprise license key
    IVIG_KEY=$(ls "${INSTALLER_DIR}"/ivig_Enterprise_*.txt 2>/dev/null | head -1)
    if [ -n "${IVIG_KEY}" ]; then
        cp "${IVIG_KEY}" "${LAB_DIR}/ivig_license.key"
    fi

    # Set JAVA_HOME and run the IVIG installer
    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    log "[ivig] Running im_installer.sh..."
    cd "${IVIG_HOME}/wlp/bin"
    ./im_installer.sh \
        -db.type POSTGRESQL \
        -db.host localhost \
        -db.port 5432 \
        -db.name "${PG_DB}" \
        -db.user "${PG_USER}" \
        -db.password "${PG_PASS}" \
        -ldap.url "ldap://localhost:${LDAP_PORT}" \
        -ldap.dn "${LDAP_ADMIN_DN}" \
        -ldap.password "${LDAP_ADMIN_PASS}" \
        -ldap.suffix "${LDAP_SUFFIX}" \
        -org.name "${IVIG_ORG}" \
        -tenant.id "${IVIG_TENANT}" \
        -admin.password "${IVIG_ADMIN_PASS}" \
        2>&1 | tee -a "${LOG_FILE}"
    cd /

    log "[ivig] Done."
fi

# ==============================================================
# STEP: service
# ==============================================================
if should_run "service"; then
    step "[service] Configuring IVIG systemd service..."

    JAVA_HOME_VAL=$(dirname $(dirname $(readlink -f $(which java) 2>/dev/null)) 2>/dev/null) || \
        JAVA_HOME_VAL="/usr/lib64/jvm/java-11-openjdk"

    cat > /etc/systemd/system/ivig.service << EOF
[Unit]
Description=IBM Verify Identity Governance (Liberty)
After=network.target postgresql.service

[Service]
Type=forking
User=root
Environment=JAVA_HOME=${JAVA_HOME_VAL}
ExecStart=${IVIG_HOME}/wlp/bin/server start defaultServer
ExecStop=${IVIG_HOME}/wlp/bin/server stop defaultServer
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ivig
    systemctl start ivig

    log "[service] IVIG service started."
fi

# ==============================================================
# STEP: wait
# ==============================================================
if should_run "wait"; then
    step "[wait] Waiting for IVIG console to become available..."

    for i in $(seq 1 30); do
        if curl -kfsS -o /dev/null "https://localhost:9443/itim/console/main" 2>/dev/null; then
            log "[wait] IVIG is ready."
            break
        fi
        log "[wait] Attempt ${i}/30 — not ready yet, waiting 20s..."
        sleep 20
    done

    log ""
    log "======================================================"
    log "  Stonewrit (IVIG) - Ready"
    log "======================================================"
    log "  Console:    https://localhost:9443/itim/console/main"
    log "  Username:   itim manager"
    log "  Password:   ${IVIG_ADMIN_PASS}"
    log "  PostgreSQL: localhost:30543 (host) / 5432 (VM)"
    log "  LDAP:       localhost:30389 (host) / 389 (VM)"
    log "  LDAPS:      localhost:30636 (host) / 636 (VM)"
    log "======================================================"
    log ""
fi

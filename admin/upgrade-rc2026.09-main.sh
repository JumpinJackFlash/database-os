#!/bin/bash

echo "To proceed you will need to enter the DBA username and schema owner names."
echo
while [ "${DBA_USER}" == '' ]; do
  read -p "Database Admin User: " DBA_USER  
  [ "${DBA_USER}" == '' ] && echo "Database Admin username must be specified."
done

while [ "${DBA_PASSWORD}" == '' ]; do
  read -sp "Database Admin Password - " DBA_PASSWORD
  echo ""
  [ "${DBA_PASSWORD}" == '' ] && echo "Database Admin Password must be specified."
done

while [ "${DATABASE_NAME}" == '' ]; do
  read -p "Enter in Database connection string or alias [${TWO_TASK}]: " DATABASE_NAME
  [ "${DATABASE_NAME}" == '' ] && DATABASE_NAME="${TWO_TASK}"
  [ "${DATABASE_NAME}" == '' ] && echo "A database connection string must be specified..."
done

read -p "Enter the name of the user that owns the DATABASE-OS schema [asteriondb_dbos]]: " DBOS_USER
[ "${DBOS_USER}" == '' ] && DBOS_USER="asteriondb_dbos"

read -p "Enter the name of the database user that owns the AsterionDB schema [asteriondb_dgbunker]: " DGBUNKER_USER
[ "${DGBUNKER_USER}" == '' ] && DGBUNKER_USER="asteriondb_dgbunker"

read -p "Enter the name of the DBOS runtime database user [dbos_runtime]: " DBOS_RUNTIME
[ "${DBOS_RUNTIME}" == '' ] && DBOS_RUNTIME="dbos_runtime"

read -p "Enter the password for the DBOS runtime database user [#SecurityBySimplicity2020#]: " DBOS_RUNTIME_PASSWORD
[ "${DBOS_RUNTIME_PASSWORD}" == '' ] && DBOS_RUNTIME_PASSWORD="#SecurityBySimplicity2020#"

cd ~/asterion/oracle/database-os/dba

echo -e "${GREEN}Upgrading Database-OS...${NC}"
sqlplus /nolog @$HOME/asterion/oracle/database-os/dba/upgrade-rc2026.09-main.sql $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBOS_USER $DGBUNKER_USER

echo -e "${GREEN}Installing vmHostMonitor service...${NC}"

sudo cp ~/asterion/oracle/database-os/admin/vmHostMonitor.service /usr/lib/systemd/system/
sudo mkdir -p /etc/systemd/system/vmHostMonitor.service.d
cat <<EOF >/tmp/append.txt
[Service]
Environment="DATABASE_NAME=${DATABASE_NAME}"
EOF
cat /tmp/append.txt | sudo tee -a /etc/systemd/system/vmHostMonitor.service.d/override.conf
sudo chmod o+w /etc/sysconfig/asterion
sudo cat <<EOF >> /etc/sysconfig/asterion
DBOS_RUNTIME=${DBOS_RUNTIME}
DBOS_RUNTIME_PASSWORD=${DBOS_RUNTIME_PASSWORD}
EOF

ln -s ~/asterion/oracle/database-os/bin/vmHostMonitor ~/asterion/oracle/bin/vmHostMonitor
cp ~/asterion/oracle/database-os/config/vmHostMonitor.sample ~/asterion/oracle/config/vmHostMonitor.config

if [ "$(/sbin/getenforce)" != 'Disabled' ]; then
  echo -e "${GREEN}Configuring SELinux...${NC}"
  [ -d ~/asterion/oracle/database-os/bin ] \
    && chcon -Rt bin_t ~/asterion/oracle/database-os/bin
fi

sudo systemctl daemon-reload




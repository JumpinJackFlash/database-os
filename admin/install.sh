#!/bin/bash

DBA_USER=''
DB_NAME=''
DBTWIG_USER=''
DGBUNKER_USER=''
DBOS_USER=''

echo "To proceed you will need to enter the DBA username and password."
echo
while [ "${DBA_USER}" == '' ]; do
  read -p "Database Admin User: " DBA_USER  
  [ "${DBA_USER}" == '' ] && echo "Database Admin username must be specified."
done

read -p "Database name [$TWO_TASK]: " DB_NAME
[ "${DB_NAME}" == '' ] && DB_NAME=$TWO_TASK

read -p "Enter the name of the database user that owns the DbTwig schema [dbtwig]: " DBTWIG_USER
[ "${DBTWIG_USER}" == '' ] && DBTWIG_USER="dbtwig"

read -p "Enter the name of the database user that owns the ICAM schema [dbtwig_icam]: " DBTWIG_ICAM
[ "${ICAM_USER}" == '' ] && ICAM_USER="dbtwig_icam"

read -p "Enter the name of the database user that owns the ELOG schema [dbtwig_elog]: " DBTWIG_ELOG
[ "${ELOG_USER}" == '' ] && ELOG_USER="dbtwig_elog"

read -p "Enter the name of the database user that owns the AsterionDB schema [asteriondb_dgbunker]: " DGBUNKER_USER
[ "${DGBUNKER_USER}" == '' ] && DGBUNKER_USER="asteriondb_dgbunker"

read -p "Enter the name of the database user that owns the AsterionDB DBOS schema [asteriondb_dbos]: " DBOS_USER
[ "${DBOS_USER}" == '' ] && DBOS_USER="asteriondb_dbos"

read -p "Enter the name of the DBOS runtime database user [dbos_runtime]: " DBOS_RUNTIME
[ "${DBOS_RUNTIME}" == '' ] && DBOS_RUNTIME="dbos_runtime"

read -p "Enter the password for the DBOS runtime database user [#SecurityBySimplicity2020#]: " DBOS_RUNTIME_PASSWORD
[ "${DBOS_RUNTIME_PASSWORD}" == '' ] && DBOS_RUNTIME_PASSWORD="#SecurityBySimplicity2020#"

set +e

cd ../dba

./createOsVariantList.sh

sqlplus /nolog @install $DBA_USER $DB_NAME $DBTWIG_USER $ELOG_USER $ICAM_USER $DGBUNKER_USER $DBOS_USER $DBOS_RUNTIME $DBOS_RUNTIME_PASSWORD

sudo cp ~/asterion/oracle/database-os/admin/vmHostMonitor.service /usr/lib/systemd/system/
sudo mkdir -p /etc/systemd/system/vmHostMonitor.service.d

if ! grep -q Service /etc/systemd/system/vmHostMonitor.service.d/override.conf; then
cat <<EOF >/tmp/append.txt
[Service]
Environment="DATABASE_NAME=${DB_NAME}"
EOF
cat /tmp/append.txt | sudo tee -a /etc/systemd/system/vmHostMonitor.service.d/override.conf
sudo chmod o+w /etc/sysconfig/asterion
sudo cat <<EOF >> /etc/sysconfig/asterion
DBOS_RUNTIME=${DBOS_RUNTIME}
DBOS_RUNTIME_PASSWORD=${DBOS_RUNTIME_PASSWORD}
EOF
fi

ln -s ~/asterion/oracle/database-os/bin/vmHostMonitor ~/asterion/oracle/bin/vmHostMonitor
cp ~/asterion/oracle/database-os/config/vmHostMonitor.sample ~/asterion/oracle/config/vmHostMonitor.config

if [ "$(/sbin/getenforce)" != 'Disabled' ]; then
  echo -e "${GREEN}Configuring SELinux...${NC}"
  [ -d ~/asterion/oracle/database-os/bin ] \
    && chcon -Rt bin_t ~/asterion/oracle/database-os/bin
fi

sudo systemctl daemon-reload

echo "AsterionDB Database OS Infrastructure installed"

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

read -p "Enter the name of the database user that owns the ELOG schema [dbtwig_elog]: " DBTWIG_ELOG
[ "${ELOG_USER}" == '' ] && ELOG_USER="dbtwig_elog"

cd ~/asterion/oracle/database-os/dba

echo -e "${GREEN}Upgrading Database-OS...${NC}"
sqlplus /nolog @$HOME/asterion/oracle/database-os/dba/upgrade-rc2026.03-main.sql $DBA_USER $DBA_PASSWORD $DATABASE_NAME $DBOS_USER $ELOG_USER



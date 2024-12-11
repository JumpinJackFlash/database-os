#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

DBA_USER=''
DBA_PASS=''
DB_NAME=''
DBTWIG_USER=''
DGBUNKER_USER=''

echo "To proceed you will need to enter the DBA username and password."
echo
while [ "${DBA_USER}" == '' ]; do
  read -p "Database Admin User: " DBA_USER  
  [ "${DBA_USER}" == '' ] && echo "Database Admin username must be specified."
done

while [ "${DBA_PASS}" == '' ]; do
  read -sp "Database Admin Password: " DBA_PASS
  echo ""
  [ "${DBA_PASS}" == '' ] && echo "Database Admin password must be specified."
done

read -p "Database name [$TWO_TASK]: " DB_NAME
[ "${DB_NAME}" == '' ] && DB_NAME=$TWO_TASK

read -p "Enter the name of the database user that owns the AsterionDB schema [asteriondb_dgbunker]: " DGBUNKER_USER
[ "${DGBUNKER_USER}" == '' ] && DGBUNKER_USER="asteriondb_dgbunker"

cd ../dba

set +e
sqlplus /nolog @install $DBA_USER $DBA_PASS $DB_NAME $DGBUNKER_USER


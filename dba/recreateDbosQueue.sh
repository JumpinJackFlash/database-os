#!/bin/bash

DBA_USER=''
DBA_PASSWORD=''

echo
echo "To proceed you will need to enter the DBA username and password."
echo

while [ "${DBA_USER}" == '' ]; do
  read -p "Database Admin username: " DBA_USER  
  echo ""
  [ "${DBA_USER}" == '' ] && echo "Database Admin username must be specified."
done

echo
read -p "AsterionDB DBOS schema username [asteriondb_dbos]: " DBOS_USER
[ "${DBOS_USER}" == '' ] && DBOS_USER='asteriondb_dbos'

sqlplus /nolog @recreateDbosQueue $DBA_USER $DBOS_USER

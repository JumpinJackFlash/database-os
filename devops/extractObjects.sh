#!/bin/bash

. $HOME/devops/settings.sh

set -e

cd "$(dirname "$0")"

sqlplus $DBOS_USER/$DBOS_PASS@$DB_NAME @extractObjects $GIT_HOME

#
#  Oracle Cloud Infrastructure
#

$SQLPATH/end_package_input.sh >>$GIT_HOME/database-os/dba/vm_manager.pls
$SQLPATH/show_errors.sh vm_manager >>$GIT_HOME/database-os/dba/vm_manager.pls 

$SQLPATH/end_package_input.sh >>$GIT_HOME/database-os/dba/vm_manager_runtime.pls
$SQLPATH/show_errors.sh vm_manager >>$GIT_HOME/database-os/dba/vm_manager_runtime.pls 

$SQLPATH/end_package_input.sh >>$GIT_HOME/database-os/dba/restapi.pls
$SQLPATH/show_errors.sh restapi >>$GIT_HOME/database-os/dba/restapi.pls 


#!/bin/bash

. $HOME/devops/settings.sh

set -e

cd "$(dirname "$0")"

sqlplus $DBOS_USER/$DBOS_PASS@$DB_NAME @extractObjects $GIT_HOME

#
#  Oracle Cloud Infrastructure
#

$SQLPATH/end_package_input.sh >>$GIT_HOME/database-os/dba/vm_manager.pls
$SQLPATH/show_errors.sh oci_interface >>$GIT_HOME/database-os/dba/vm_manager.pls 


#!/bin/bash

. $HOME/devops/settings.sh

set -e

cd "$(dirname "$0")"

sqlplus $OBJVAULT_USER/$OBJVAULT_PASS@$DB_NAME @extractObjects $GIT_HOME

#
#  Oracle Cloud Infrastructure
#

$SQLPATH/end_package_input.sh >>$GIT_HOME/digitalBunker/extensions/virtualMachines/dba/vm_manager.pls
$SQLPATH/show_errors.sh oci_interface >>$GIT_HOME/digitalBunker/extensions/virtualMachines/dba/vm_manager.pls 


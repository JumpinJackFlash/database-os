define git_home = &1

rem
rem  AsterionDB DBOS
rem

set echo on

@extractPackageHeader vm_manager &git_home/database-os/dba
@preWrapPackageBody vm_manager &git_home/database-os/dba

@extractPackageHeader vm_manager_runtime &git_home/database-os/dba
@preWrapPackageBody vm_manager_runtime &git_home/database-os/dba

@extractPackageHeader restapi &git_home/database-os/dba
@preWrapPackageBody restapi &git_home/database-os/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/database-os/dba/dbTwigData.sql dbos

exit;

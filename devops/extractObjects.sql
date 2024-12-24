define git_home = &1

rem
rem  AsterionDB DBOS
rem

@extractPackageHeader vm_manager &git_home/database-os/dba
@preWrapPackageBody vm_manager &git_home/database-os/dba

@&git_home/dbTwig/dba/extractDbTwigData &git_home/database-os/dba/dbTwigData.sql database_os

exit;

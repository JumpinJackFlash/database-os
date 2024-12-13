define git_home = &1

rem
rem  Oracle Cloud Infrastructure
rem

@extractPackageHeader vm_manager &git_home/database-os/dba
@preWrapPackageBody vm_manager &git_home/database-os/dba

exit;

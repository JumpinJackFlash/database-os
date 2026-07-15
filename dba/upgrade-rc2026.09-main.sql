/*



*/

define dba_user = '&1'
define dba_password = '&2'
define db_name = '&3'
define dbos_user = '&4'
define elog_user = '&5'

spool $HOME/asterion/oracle/database-os/dba/upgrade-rc2026.09-main.log

whenever sqlerror exit
connect &dba_user/"&dba_password"@"&db_name"

set echo on

alter session set current_schema = &dbos_user;
whenever sqlerror continue

REM  Put stuff between here.....

alter table virtual_machines add start_on_system_boot varchar2(1) default 'N' not null constraint start_on_chk check (start_on_system_boot in ('Y', 'N'));

REM  ...and here

@loadPackages

set echo on

delete  from middle_tier_map
 where  object_group in ('dbos');

commit;

@$HOME/asterion/oracle/database-os/dba/dbTwigData

commit;


prompt 
spool off;

exit;

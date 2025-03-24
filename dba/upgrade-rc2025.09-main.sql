/*



*/

define dba_user = '&1'
define dba_password = '&1'
define dbos_user = '&3'

spool $HOME/asterion/oracle/database-os/dba/upgrade-rc2025.09-main.log

whenever sqlerror exit
connect &dba_user/"&dba_password"@"&db_name"

set echo on

alter session set current_schema = &dbos_user;
whenever sqlerror continue

REM  Put stuff between here.....



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


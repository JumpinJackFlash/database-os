/*



*/

define dba_user = '&1'
define dba_password = '&2'
define db_name = '&3'
define dbos_user = '&4'
define elog_user = '&5'
define runtime_user = 'dbos_runtime'
define runtime_password = '#SecurityBySimplicity2020#'

spool $HOME/asterion/oracle/database-os/dba/upgrade-rc2026.03-main.log

whenever sqlerror exit
connect &dba_user/"&dba_password"@"&db_name"

set echo on

alter session set current_schema = &dbos_user;
whenever sqlerror continue

REM  Put stuff between here.....

alter table virtual_machines drop constraint state_detail_chk;

alter table virtual_machines add constraint state_detail_chk check (state_detail in ('unknown', 'shutdown finished', 'guest initiated', 'host initiated', 
      'normal shutdown', 'host poweroff', 'guest crashed', 'migrated', 'saved', 'host failed', 'snapshot loaded', 'normal startup', 
      'incoming migration', 'restored state', 'restored snapshot', 'wakeup event', 'normal resume', 'migration complete', 
      'snapshot complete', 'migration running', 'migration failed', 'startup requested', 'install failed', 'startup failed'));

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

/*



*/

define dba_user = '&1'
define dba_password = '&2'
define db_name = '&3'
define dbos_user = '&4'
define elog_user = '&5'
define runtime_user = 'dbos_runtime'
define runtime_password = '#SecurityBySimplicity2020#'

spool $HOME/asterion/oracle/database-os/dba/upgrade-rc2025.09-main.log

whenever sqlerror exit
connect &dba_user/"&dba_password"@"&db_name"

set echo on

alter session set current_schema = &dbos_user;
whenever sqlerror continue

REM  Put stuff between here.....

declare

    l_sql_text                        clob;
  
begin

    l_sql_text := 'grant create session to &runtime_user identified by "&runtime_password"';
    execute immediate l_sql_text;

end;
.
/

grant execute on &elog_user..error_logger to &dbos_user;
create or replace synonym &dbos_user..error_logger for &elog_user..error_logger;

grant read on &elog_user..api_errors to &dbos_user;
create or replace synonym &dbos_user..api_errors for &elog_user..api_errors;

grant execute on dbms_aq to &dbos_user;
grant execute on dbms_aqadm to &dbos_user;

create or replace type dbos$message_t as object
(
  client_handle					      varchar2(24),
  host_name                           varchar2(256),
  message_type					      number(4),
  message_payload				      varchar2(4000)
);
.
/

show errors type dbos$message_t

@createQueue &dbos_user

create table vm_hosts
(
  host_id                           number(12) primary key,
  host_name                         varchar2(256) unique not null,
  sysinfo                           xmltype,
  host_capabilities                 xmltype,
  hypervisor_version                number(8),
  libvirt_version                   number(8),
  os_release                        varchar2(64),
  machine_type                      varchar2(64),
  status                            varchar2(7) default 'offline' not null,
    constraint vm_host_status_chk check (status in ('offline', 'online')),
  last_update                       timestamp
);

alter table virtual_machines drop column assigned_to_host;

alter table virtual_machines add host_id number(7) references vm_hosts(host_id);
alter table virtual_machines add uuid varchar2(36) unique;
alter table virtual_machines add persistent varchar2(1) default 'N' not null constraint persistent_chk check (persistent in ('Y', 'N'));
alter table virtual_machines add interfaces clob constraint interfaces_chk check(interfaces is json);

alter table virtual_machines add lifecycle_state varchar2(11) default 'stopped' not null
  constraint lifecycle_state_chk check (lifecycle_state in ('unknown', 'start', 'starting', 'running', 'blocked', 'pausing', 'paused', 'stop', 
      'stopping', 'stopped', 'crashed', 'pmsuspended'));

alter table virtual_machines add state_detail varchar2(30) default 'unknown' not null
    constraint state_detail_chk check (state_detail in ('unknown', 'shutdown finished', 'guest initiated', 'host initiated', 
      'normal shutdown', 'host poweroff', 'guest crashed', 'migrated', 'saved', 'host failed', 'snapshot loaded', 'normal startup', 
      'incoming migration', 'restored state', 'restored snapshot', 'wakeup event', 'normal resume', 'migration complete', 
      'snapshot complete', 'migration running', 'migration failed', 'startup requested', 'install failed'));

alter table virtual_machines add xml_description xmltype;

REM  ...and here

@loadPackages

grant execute on &dbos_user..vm_manager_runtime to &runtime_user;
create synonym &runtime_user..vm_manager_runtime for &dbos_user..vm_manager_runtime;

set echo on

delete  from middle_tier_map
 where  object_group in ('dbos');

commit;

@$HOME/asterion/oracle/database-os/dba/dbTwigData

commit;


prompt 
spool off;

exit;

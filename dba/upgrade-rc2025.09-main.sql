/*



*/

define dba_user = '&1'
define dba_password = '&2'
define db_name = '&3'
define dbos_user = '&4'
define runtime_user = '&5'
define runtime_password = '&6'

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

grant execute on dbms_aq to &dbos_user;
grant execute on dbms_aqadm to &dbos_user;

create or replace type dbos$message_t as object
(
  client_handle					      varchar2(24),
  message_type					      number(4),
  message_payload				      varchar2(4000)
);
.
/

show errors type dbos$message_t

@createQueue

create table vm_hosts
(
  host_id                           number(12) primary key,
  host_name                         varchar2(256) unique not null,
  status                            varchar2(7) default 'offline' not null,
    constraint vm_host_status_chk check (status in ('offline', 'online')),
  last_heartbeat                    timestamp
);

alter table virtual_machines drop column assigned_to_host;

alter table virtual_machines add default_host_id number(7) references vm_hosts(host_id);
alter table virtual_machines add assigned_to_host_id number(7) references vm_hosts(host_id);

REM  ...and here

@loadPackages

grant execute on vm_manager_runtime to &runtime_user;

set echo on

delete  from middle_tier_map
 where  object_group in ('dbos');

commit;

@$HOME/asterion/oracle/database-os/dba/dbTwigData

commit;


prompt 
spool off;

exit;

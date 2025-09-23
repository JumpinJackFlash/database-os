/*



*/

define dba_user = '&1'
define dba_password = '&2'
define db_name = '&3'
define dbos_user = '&4'
define elog_user = '&5'
define runtime_user = 'dbos_runtime'
define runtime_password = '#SecurityBySimplicity2020#'

spool $HOME/asterion/oracle/database-os/dba/upgrade-2025.09-main.log

whenever sqlerror exit
connect &dba_user/"&dba_password"@"&db_name"

set echo on

alter session set current_schema = &dbos_user;
whenever sqlerror continue

REM  Put stuff between here.....

alter table virtual_machines drop column virtual_cdrom_id;
alter table virtual_machines rename column virtual_disk_id to boot_disk_id;

alter table virtual_machines drop constraint lifecycle_state_chk;

alter table virtual_machines add constraint lifecycle_state_chk check (lifecycle_state in ('unknown', 'start', 'starting', 'running', 'blocked', 'pausing', 
      'paused', 'stop', 'stopping', 'stopped', 'crashed', 'pmsuspended', 'create'));

create table virtual_disks
(
  virtual_disk_id                   number(12) primary key,
  object_id                         varchar2(32) unique
    references vault_objects(object_id),
  disk_name                         varchar2(60) unique not null,
  disk_size                         number(4) default 1 not null,
  sparse_allocation                 varchar2(1) default 'Y' not null
    constraint vd_sparse_chk check (sparse_allocation in ('Y', 'N'))
);

create table attached_storage
(
  virtual_disk_id                   number(12) 
    references virtual_disks(virtual_disk_id),
  virtual_machine_id                number(12) not null
    references virtual_machines(virtual_machine_id),
  disk_number                       number(3) default 1 not null
);

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

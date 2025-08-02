rem  Copyright (c) 2020 By AsterionDB Inc.
rem
rem  install.sql 	AsterionDB DBOS
rem
rem  Written By:  Steve Guilford
rem
rem  This SQL script drives the creation of all required objects for the AsterionDB DBOS.
rem
rem  Invocation: sqlplus /nolog @install $DBA_USER $DATABASE_NAME $DBTWIG_USER $DGBUNKER_USER $DBOS_USER

whenever sqlerror exit failure;

set verify off
spool install.log

define dba_user = '&1'
define database_name = '&2'
define dbtwig_user = '&3'
define elog_user = '&4'
define icam_user = '&5'
define dgbunker_user = '&6'
define dbos_user = '&7'
define runtime_user = 'dbos_runtime'
define runtime_password = '#SecurityBySimplicity2020#'

connect &dba_user@"&database_name";

set termout on
set echo on

whenever sqlerror continue

declare

    l_sql_text                        clob;
    l_default_tablespace              database_properties.property_value%type;

begin

    select  property_value
      into  l_default_tablespace
      from  database_properties 
     where  property_name = 'DEFAULT_PERMANENT_TABLESPACE';

    l_sql_text := 'create user &dbos_user';
    execute immediate l_sql_text;

    l_sql_text := 'alter user &dbos_user quota 50M on '||l_default_tablespace;
    execute immediate l_sql_text;

end;
.
/

declare

    l_sql_text                        clob;
  
begin

    l_sql_text := 'grant create session to &runtime_user identified by "&runtime_password"';
    execute immediate l_sql_text;

end;
.
/

set verify on

create or replace synonym &dbos_user..db_twig for &dbtwig_user..db_twig;
grant execute on &dbtwig_user..db_twig to &dbos_user;

create or replace synonym &dbos_user..vault_objects for &dgbunker_user..vault_objects;
grant references(object_id), read on &dgbunker_user..vault_objects to &dbos_user;

create or replace synonym &dbos_user..dgbunker_service for &dgbunker_user..dgbunker_service;
grant execute on &dgbunker_user..dgbunker_service to &dbos_user;

create or replace synonym &dbos_user..dbplugin_api for &dgbunker_user..dbplugin_api;
grant execute on &dgbunker_user..dbplugin_api to &dbos_user;

create or replace synonym &dbos_user..icam for &icam_user..icam;
grant execute on &icam_user..icam to &dbos_user;

create or replace synonym &dbos_user..icam_users for &icam_user..icam_users;
grant references(user_id), read on &icam_user..icam_users to &dbos_user;

grant execute on &elog_user..error_logger to &dbos_user;
create or replace synonym &dbos_user..error_logger for &elog_user..error_logger;

grant read on &elog_user..api_errors to &dbos_user;
create or replace synonym &dbos_user..api_errors for &elog_user..api_errors;

grant execute on dbms_aq to &dbos_user;
grant execute on dbms_aqadm to &dbos_user;

alter session set current_schema = &dbos_user;

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

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

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

create table virtual_machines
(
  virtual_machine_id                number(12) primary key,
  creation_timestamp                timestamp default systimestamp at time zone 'utc' not null,
  machine_name                      varchar2(30) unique not null,
  virtual_disk_id                   varchar2(32) unique
    references vault_objects(object_id),
  virtual_cdrom_id                  varchar2(32)
    references vault_objects(object_id),
  vcpu_count                        number(4),
  virtual_memory                    number(6),
  os_variant                        varchar2(30),
  uuid                              varchar2(36),
  persistent                        varchar2(1) default 'N' not null
    constraint persistent_chk check (persistent in ('Y', 'N')),
  lifecycle_state                   varchar2(11) default 'stopped' not null
    constraint lifecycle_state_chk check (lifecycle_state in ('unknown', 'start', 'starting', 'running', 'blocked', 'pausing', 
      'paused', 'stop', 'stopping', 'stopped', 'crashed', 'pmsuspended')),
  state_detail                      varchar2(30) default 'unknown' not null
    constraint state_detail_chk check (state_detail in ('unknown', 'shutdown finished', 'guest initiated', 'host initiated', 
      'normal shutdown', 'host poweroff', 'guest crashed', 'migrated', 'saved', 'host failed', 'snapshot loaded', 'normal startup', 
      'incoming migration', 'restored state', 'restored snapshot', 'wakeup event', 'normal resume', 'migration complete', 
      'snapshot complete', 'migration running', 'migration failed', 'startup requested', 'install failed')),
  network_source                    varchar2(30),
  network_device                    varchar2(30),
  interfaces                        clob
    constraint interfaces_chk check(interfaces is json),
  host_id                           number(7)
    references vm_hosts(host_id),
  xml_description                   xmltype
);

create table os_variants
(
  variant_id                        number(7) primary key,
  variant                           varchar2(30) unique not null,
  long_name                         varchar2(64) not null
);

@$HOME/asterion/oracle/dbTwig/dba/middleTierMap.sql
@$HOME/asterion/oracle/database-os/dba/dbTwigData.sql

@$HOME/asterion/oracle/database-os/dba/loadPackages.sql

grant execute on &dbos_user..vm_manager_runtime to &runtime_user;
create synonym &runtime_user..vm_manager_runtime for &dbos_user..vm_manager_runtime;

grant execute on &dbos_user..restapi to &dbtwig_user;
grant select on &dbos_user..middle_tier_map to &dbtwig_user;

begin vm_manager.create_dbos_service; end;
.
/

commit;
exit;



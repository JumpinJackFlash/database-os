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
define icam_user = '&4'
define dgbunker_user = '&5'
define dbos_user = '&6'

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

alter session set current_schema = &dbos_user;

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

create table virtual_machines
(
  virtual_machine_id                number(12) primary key,
  user_id                           number(12) not null
    references icam_users(user_id),
  creation_timestamp                timestamp default systimestamp at time zone 'utc' not null,
  machine_name                      varchar2(30) unique not null,
  virtual_disk_id                   varchar2(32) unique
    references vault_objects(object_id),
  virtual_cdrom_id                  varchar2(32)
    references vault_objects(object_id),
  vcpu_count                        number(4),
  virtual_memory                    number(6),
  os_variant                        varchar2(30),
  network_source                    varchar2(30),
  network_device                    varchar2(30),
  assigned_to_host                  varchar2(256)
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

grant execute on &dbos_user..restapi to &dbtwig_user;
grant select on &dbos_user..middle_tier_map to &dbtwig_user;

begin vm_manager.create_dbos_service; end;
.
/

commit;
exit;



create or replace synonym asteriondb_dbos.db_twig for dbtwig.db_twig;
grant execute on dbtwig.db_twig to asteriondb_dbos;

create or replace synonym asteriondb_dbos.vault_objects for asteriondb_dgbunker.vault_objects;
grant references(object_id), read on asteriondb_dgbunker.vault_objects to asteriondb_dbos;

create or replace synonym asteriondb_dbos.dgbunker_service for asteriondb_dgbunker.dgbunker_service;
grant execute on asteriondb_dgbunker.dgbunker_service to asteriondb_dbos;

create or replace synonym asteriondb_dbos.dbplugin_api for asteriondb_dgbunker.dbplugin_api;
grant execute on asteriondb_dgbunker.dbplugin_api to asteriondb_dbos;

create or replace synonym asteriondb_dbos.icam for dbtwig_icam.icam;
grant execute on dbtwig_icam.icam to asteriondb_dbos;

create sequence id_seq minvalue 1 maxvalue 999999999999 cycle;

create table virtual_machines
(
  vm_id                             number(12) primary key,
  user_id                           number(12) not null
    references object_vault_users(user_id),
  creation_timestamp                timestamp default systimestamp at time zone 'utc' not null,
  machine_name                      varchar2(30) unique not null,
  virtual_disk_id                   varchar2(32)
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

@$HOME/asterion/oracle/dbTwig/dba/middleTierMap.sql

grant execute on &4..restapi to &3;
grant select on &4..middle_tier_map to &3;

begin vm_manager.create_dbos_service; end;
.
/

commit;


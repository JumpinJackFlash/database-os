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

insert into object_vault_extensions values ('Virtual Machines', '{}');

commit;

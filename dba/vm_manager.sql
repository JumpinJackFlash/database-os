create or replace
package vm_manager

as

  function create_cloud_init_cdrom_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_local_hostname                  varchar2,
    p_user                            varchar2,
    p_password                        varchar2,
    p_authorized_ssh_keys             json_array_t,
    p_ip4_address                     varchar2,
    p_ip4_gateway                     varchar2,
    p_ip4_netmask                     varchar2,
    p_dns_nameservers                 json_array_t,
    p_dns_search                      clob
  )
  return vault_objects.object_id%type;

  function create_cloud_init_cdrom_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_meta_data_file                  vault_objects.object_id%type,
    p_user_data_file                  vault_objects.object_id%type,
    p_network_config_file             vault_objects.object_id%type
  )
  return vault_objects.object_id%type;

  function create_cloud_init_cdrom_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_meta_data                       clob,
    p_user_data                       clob,
    p_network_config                  clob
  )
  return vault_objects.object_id%type;

  procedure create_dbos_service;

  procedure create_seed_from_virtual_disk
  (
    p_session_id                      varchar2,
    p_seed_image_name                 varchar2,
    p_virtual_disk_id                 virtual_machines.virtual_disk_id%type
  );

  function create_virtual_disk_from_seed
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2,
    p_seed_image_id                   vault_objects.object_id%type
  )
  return vault_objects.object_id%type;

  function create_boot_disk
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2
  )
  return clob;

  procedure create_vm_from_iso_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_iso_image_id                    virtual_machines.virtual_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  );

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.virtual_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_meta_data                       clob,
    p_user_data                       clob,
    p_network_config                  clob,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  );

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.virtual_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_user                            varchar2,
    p_local_hostname                  varchar2,
    p_password                        varchar2 default null,
    p_ip4_address                     varchar2 default null,
    p_ip4_netmask                     varchar2 default null,
    p_ip4_gateway                     varchar2 default null,
    p_dns_search                      clob default null,
    p_nameservers                     json_array_t default null,
    p_ssh_keys                        json_array_t default null,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  );

  procedure delete_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_delete_boot_disk                boolean
  );

  function get_iso_seed_images
  (
    p_session_id                      varchar2
  )
  return clob;

  function get_os_variants return clob;

  function get_qcow2_seed_images
  (
    p_session_id                      varchar2
  )
  return clob;

  function get_service_data return clob;

  function get_virtual_machines return clob;

  function get_vm_host_name
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return vm_hosts.host_name%type;

  procedure import_virtual_machine
  (
    p_object_id                       vault_objects.object_id%type,
    p_machine_name                    virtual_machines.machine_name%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  );

  procedure start_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_boot_device                     varchar2 default 'hd'
  );

  procedure stop_virtual_machine
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  );

  procedure undefine_virtual_machine
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  );

end vm_manager;
.
/
show errors package vm_manager

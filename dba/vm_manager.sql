create or replace
package vm_manager

as

  function create_cloud_init_cdrom_image
  (
    p_machine_name                    virtual_machines.machine_name%type,
    p_local_hostname                  varchar2,
    p_user                            varchar2,
    p_authorized_ssh_keys             json_array_t,
    p_network_device_name             varchar2,
    p_ip4_address                     varchar2,
    p_ip4_gateway                     varchar2,
    p_ip4_netmask                     varchar2,
    p_dns_nameservers                 json_array_t,
    p_dns_search                      json_array_t
  )
  return vault_objects.object_id%type;

  function create_cloud_init_cdrom_image
  (
    p_machine_name                    virtual_machines.machine_name%type,
    p_meta_data_file                  vault_objects.object_id%type,
    p_user_data_file                  vault_objects.object_id%type,
    p_network_config_file             vault_objects.object_id%type
  )
  return vault_objects.object_id%type;

  procedure create_dbos_service;

  function create_virtual_disk
  (
    p_disk_image_name                 varchar2,
    p_seed_image_id                   vault_objects.object_id%type
  )
  return vault_objects.object_id%type;

  function create_virtual_disk
  (
    p_disk_image_name                 varchar2
  )
  return vault_objects.object_id%type;

  function create_virtual_machine
  (
    p_machine_name                    virtual_machines.machine_name%type,
    p_virtual_disk_id                 virtual_machines.virtual_disk_id%type,
    p_os_variant                      virtual_machines.os_variant%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_virtual_cdrom_id                virtual_machines.virtual_cdrom_id%type default null,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_network_source                  virtual_machines.network_source%type default 'network',
    p_network_device                  virtual_machines.network_device%type default 'default',
    p_remove_cdrom_after_first_boot   varchar2 default 'Y',
    p_boot_device                     varchar2 default 'hd'
  )
  return virtual_machines.vm_id%type;

  procedure delete_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  );

  function get_list_of_virtual_machines
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  function get_service_data
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  procedure start_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type,
    p_boot_device                     varchar2 default 'hd'
  );

  procedure stop_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  );

  procedure undefine_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  );

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end vm_manager;
.
/
show errors package vm_manager

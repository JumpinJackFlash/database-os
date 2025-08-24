create or replace
package vm_manager

as

  SERVICE_NAME                        constant varchar2(4) := 'dbos';

  MESSAGE_EXPIRATION                  constant pls_integer := 5;
  MESSAGE_QUEUE                       constant varchar2(17) := 'dbos$vm_monitor_q';

-- These values are tied to the message types handled by the vmHostMonitor (vmHostMonitorDefs.h)

  HOST_MONITOR_REPLY_MESSAGE          constant pls_integer := 10;
  CREATE_VM_MESSAGE                   constant pls_integer := 20;
  STOP_VM_MESSAGE                     constant pls_integer := 25;
  UNDEFINE_VM_MESSAGE                 constant pls_integer := 30;
  CREATE_CLOUD_INIT_CDROM_MESSAGE     constant pls_integer := 35;
  DELETE_STORAGE_POOL_MESSAGE         constant pls_integer := 40;
  START_VM_MESSAGE                    constant pls_integer := 45;

-- Error codes and messages. DbTwig has reserved -20000 to -20199. Start with -20200

  UNAUTHORIZED_VM_DETECTED            constant pls_integer := -20200;
  UNAUTHORIZED_VM_DETECTED_EMSG       constant varchar2(45) := 'A VM was detected that should not be running.';

  VM_STATE_MISMATCH                   constant pls_integer := -20201;
  VM_STATE_MISMATCH_EMSG              constant varchar2(33) := 'A VM state mismatch was detected.';

  VM_HOST_OFFLINE                     constant pls_integer := -20202;
  VM_HOST_OFFLINE_EMSG                constant varchar2(62) := 'Assigned host server for specified virtual machine is offline.';

/*  function create_cloud_init_cdrom_image
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
  return vault_objects.object_id%type; */

  procedure clear_lazy_ref_bit
  (
    p_object_id                       vault_objects.object_id%type
  );

  procedure create_dbos_service;

  procedure create_seed_from_virtual_disk
  (
    p_session_id                      varchar2,
    p_seed_image_name                 varchar2,
    p_boot_disk_id                    virtual_machines.boot_disk_id%type
  );

  function create_virtual_disk_from_seed
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2,
    p_seed_image_id                   vault_objects.object_id%type
  )
  return vault_objects.object_id%type;

  function create_virtual_disk
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2
  )
  return clob;

  procedure create_vm_from_iso_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_iso_image_id                    vault_objects.object_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_host_id                         vm_hosts.host_id%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default',
    p_attached_storage                json_array_t default null
  );

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.boot_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_host_id                         vm_hosts.host_id%type,
    p_meta_data                       clob,
    p_user_data                       clob,
    p_network_config                  clob,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default',
    p_attached_storage                json_array_t default null
  );

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.boot_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_host_id                         vm_hosts.host_id%type,
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
    p_network_device                  virtual_machines.network_device%type default 'default',
    p_attached_storage                json_array_t default null
  );

  procedure delete_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_delete_boot_disk                boolean
  );

  function get_cpu_count
  (
    p_host_capabilities               vm_hosts.host_capabilities%type
  )
  return pls_integer;

  function get_cpu_count
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return pls_integer;

  function get_installed_memory
  (
    p_host_capabilities               vm_hosts.host_capabilities%type
  )
  return pls_integer;

  function get_installed_memory
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return pls_integer;

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

  function get_virtual_machine_description
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  function get_virtual_machines return clob;

  function get_vm_host_name
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return vm_hosts.host_name%type;

  function get_vm_hosts return clob;

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

  procedure register_vm_host
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  );

  procedure send_message_to_host_monitor
  (
    p_message                         dbos$message_t
  );

  procedure set_persistent
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_persistent                      virtual_machines.persistent%type
  );

  procedure set_vm_host_offline
  (
    p_host_name                       vm_hosts.host_name%type
  );

  procedure start_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  );

  procedure stop_virtual_machine
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  );

  procedure update_lifecycle_state
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  );

  procedure update_vm_description
  (
    p_json_parameters                 json_object_t
  );

  procedure update_vm_info
  (
    p_json_parameters                 json_object_t
  );

  procedure update_vm_state
  (
    p_json_parameters                 json_object_t
  );

  procedure validate_vm_state
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  );

end vm_manager;
.
/
show errors package vm_manager

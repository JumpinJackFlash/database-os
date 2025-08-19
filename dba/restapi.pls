create or replace
package body restapi as

  procedure create_vm_from_iso_image
  (
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_iso_image_id                    vault_objects.object_id%type := db_twig.get_string(p_json_parameters, 'isoImageId');
    l_os_variant_id                   pls_integer := db_twig.get_number(p_json_parameters, 'osVariantId');
    l_host_id                         vm_hosts.host_id%type := db_twig.get_string(p_json_parameters, 'hostId');
    l_virtual_disk_size               pls_integer := db_twig.get_string(p_json_parameters, 'virtualDiskSize');
    l_sparse_disk_allocation          varchar2(1) := db_twig.get_string(p_json_parameters, 'sparseDiskAllocation');
    l_vcpu_count                      virtual_machines.vcpu_count%type := db_twig.get_string(p_json_parameters, 'vcpuCount');
    l_virtual_memory                  virtual_machines.virtual_memory%type := db_twig.get_string(p_json_parameters, 'virtualMemory');
    l_bridged_connection              varchar2(1) := db_twig.get_string(p_json_parameters, 'bridgedConnection');
    l_network_device                  virtual_machines.network_device%type := db_twig.get_string(p_json_parameters, 'networkDevice');
    l_attached_storage                json_array_t := db_twig.get_array(p_json_parameters, 'attachedStorage');

  begin

    vm_manager.create_vm_from_iso_image(icam.extract_session_id(p_json_parameters), l_machine_name, l_iso_image_id, l_os_variant_id,
      l_host_id, l_virtual_disk_size, l_sparse_disk_allocation, l_vcpu_count, l_virtual_memory, l_bridged_connection, l_network_device,
      l_attached_storage);

  end create_vm_from_iso_image;

  procedure create_vm_from_qcow_image
  (
    p_json_parameters                 json_object_t
  )

  is

    l_config                          varchar2(8) := db_twig.get_string(p_json_parameters, 'config');
    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_qcow_image_id                   virtual_machines.boot_disk_id%type := db_twig.get_string(p_json_parameters, 'qcowImageId');
    l_os_variant_id                   pls_integer := db_twig.get_number(p_json_parameters, 'osVariantId');
    l_host_id                         vm_hosts.host_id%type := db_twig.get_string(p_json_parameters, 'hostId');
    l_vcpu_count                      virtual_machines.vcpu_count%type := db_twig.get_string(p_json_parameters, 'vcpuCount');
    l_virtual_memory                  virtual_machines.virtual_memory%type := db_twig.get_string(p_json_parameters, 'virtualMemory');
    l_bridged_connection              varchar2(1) := db_twig.get_string(p_json_parameters, 'bridgedConnection');
    l_network_device                  virtual_machines.network_device%type := db_twig.get_string(p_json_parameters, 'networkDevice');
    l_attached_storage                json_array_t := db_twig.get_array(p_json_parameters, 'attachedStorage');
    l_meta_data                       clob;
    l_user_data                       clob;
    l_network_config                  clob;
    l_ip4_address                     varchar2(15);
    l_ip4_netmask                     varchar2(15);
    l_ip4_gateway                     varchar2(15);
    l_dns_search                      clob;
    l_nameservers                     json_array_t;
    l_ssh_keys                        json_array_t;
    l_user                            varchar2(30);
    l_password                        varchar2(30);
    l_local_hostname                  varchar2(132);

  begin

    if 'files' = l_config then

      l_meta_data := db_twig.get_clob(p_json_parameters, 'metaData');
      l_user_data := db_twig.get_clob(p_json_parameters, 'userData');
      l_network_config := db_twig.get_clob(p_json_parameters, 'networkConfig');

      vm_manager.create_vm_from_qcow_image(icam.extract_session_id(p_json_parameters), l_machine_name, l_qcow_image_id, l_os_variant_id,
        l_host_id, l_meta_data, l_user_data, l_network_config, l_vcpu_count, l_virtual_memory, l_bridged_connection, l_network_device,
        l_attached_storage);

    else

      l_ip4_address := db_twig.get_string(p_json_parameters, 'ip4Address');
      l_ip4_netmask := db_twig.get_string(p_json_parameters, 'ip4Netmask');
      l_ip4_gateway := db_twig.get_string(p_json_parameters, 'ip4Gateway');
      l_dns_search := db_twig.get_clob(p_json_parameters, 'dnsSearch');
      l_nameservers := db_twig.get_array(p_json_parameters, 'nameservers');
      l_ssh_keys := db_twig.get_array(p_json_parameters, 'sshKeys');
      l_user := db_twig.get_string(p_json_parameters, 'user');
      l_password := db_twig.get_string(p_json_parameters, 'password');
      l_local_hostname := db_twig.get_string(p_json_parameters, 'localhost_name');

      vm_manager.create_vm_from_qcow_image(icam.extract_session_id(p_json_parameters), l_machine_name, l_qcow_image_id, l_os_variant_id,
        l_host_id, l_user, l_local_hostname, l_password, l_ip4_address, l_ip4_netmask, l_ip4_gateway, l_dns_search, l_nameservers,
        l_ssh_keys, l_vcpu_count, l_virtual_memory, l_bridged_connection, l_network_device, l_attached_storage);

    end if;

  end create_vm_from_qcow_image;

  procedure delete_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  is

    l_virtual_machine_id              virtual_machines.virtual_machine_id%type;
    l_delete_boot_disk                boolean;

  begin

    l_virtual_machine_id := db_twig.get_number(p_json_parameters, 'virtualMachineId');
    l_delete_boot_disk := db_twig.get_boolean(p_json_parameters, 'deleteBootDisk');
    vm_manager.delete_virtual_machine(icam.extract_session_id(p_json_parameters), l_virtual_machine_id, l_delete_boot_disk);

  end delete_virtual_machine;

  function get_iso_seed_images
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_iso_seed_images(icam.extract_session_id(p_json_parameters));

  end get_iso_seed_images;

  function get_os_variants
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_os_variants;

  end get_os_variants;

  function get_qcow2_seed_images
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_qcow2_seed_images(icam.extract_session_id(p_json_parameters));

  end get_qcow2_seed_images;

  function get_service_data
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_service_data;

  end get_service_data;

  function get_virtual_machines
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_virtual_machines;

  end get_virtual_machines;

  function get_vm_hosts
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_vm_hosts();

  end get_vm_hosts;

  procedure set_persistent
  (
    p_json_parameters                 json_object_t
  )

  is

    l_virtual_machine_id              virtual_machines.virtual_machine_id%type := db_twig.get_number(p_json_parameters, 'virtualMachineId');
    l_persistent                      virtual_machines.persistent%type := db_twig.get_string(p_json_parameters, 'persistent');

  begin

    vm_manager.set_persistent(l_virtual_machine_id, l_persistent);

  end set_persistent;

  procedure start_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  as

    l_virtual_machine_id              virtual_machines.virtual_machine_id%type := db_twig.get_number(p_json_parameters, 'virtualMachineId');

  begin

    vm_manager.start_virtual_machine(icam.extract_session_id(p_json_parameters), l_virtual_machine_id);

  end start_virtual_machine;

  procedure stop_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  as

    l_virtual_machine_id              virtual_machines.virtual_machine_id%type := db_twig.get_number(p_json_parameters, 'virtualMachineId');

  begin

    vm_manager.stop_virtual_machine(l_virtual_machine_id);

  end stop_virtual_machine;

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  )

  is

  begin

    icam.validate_session(p_json_parameters, p_required_authorization_level, p_allow_blocked_session);

  end validate_session;

end restapi;
/
show errors package body restapi

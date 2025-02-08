create or replace
package body restapi as

  procedure create_vm_from_iso_image
  (
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string_parameter(p_json_parameters, 'machineName');
    l_iso_image_id                    virtual_machines.virtual_disk_id%type := db_twig.get_string_parameter(p_json_parameters, 'isoImageId');
    l_os_variant_id                   pls_integer := db_twig.get_number_parameter(p_json_parameters, 'osVariantId');
    l_virtual_disk_size               pls_integer := db_twig.get_string_parameter(p_json_parameters, 'virtualDiskSize');
    l_sparse_disk_allocation          varchar2(1) := db_twig.get_string_parameter(p_json_parameters, 'sparseDiskAllocation');
    l_vcpu_count                      virtual_machines.vcpu_count%type := db_twig.get_string_parameter(p_json_parameters, 'vcpuCount');
    l_virtual_memory                  virtual_machines.virtual_memory%type := db_twig.get_string_parameter(p_json_parameters, 'virtualMemory');
    l_bridged_connection              varchar2(1) := db_twig.get_string_parameter(p_json_parameters, 'bridgedConnection');
    l_network_device                  virtual_machines.network_device%type := db_twig.get_string_parameter(p_json_parameters, 'networkDevice');

  begin

    vm_manager.create_vm_from_iso_image(icam.extract_session_id(p_json_parameters), l_machine_name, l_iso_image_id, l_os_variant_id,
      l_virtual_disk_size, l_sparse_disk_allocation, l_vcpu_count, l_virtual_memory, l_bridged_connection, l_network_device);

  end create_vm_from_iso_image;

  function get_iso_images
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_iso_images(icam.extract_session_id(p_json_parameters));

  end get_iso_images;

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

  function get_os_variants
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

  begin

    return vm_manager.get_os_variants;

  end get_os_variants;

  procedure start_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  as

    l_vm_id                           virtual_machines.vm_id%type := db_twig.get_number_parameter(p_json_parameters, 'vmId');

  begin

    vm_manager.start_virtual_machine(icam.extract_session_id(p_json_parameters), l_vm_id);

  end start_virtual_machine;

  procedure stop_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  as

    l_vm_id                           virtual_machines.vm_id%type := db_twig.get_number_parameter(p_json_parameters, 'vmId');

  begin

    vm_manager.stop_virtual_machine(l_vm_id);

  end stop_virtual_machine;

  procedure undefine_virtual_machine
  (
    p_json_parameters                 json_object_t
  )

  as

    l_vm_id                           virtual_machines.vm_id%type := db_twig.get_number_parameter(p_json_parameters, 'vmId');

  begin

    vm_manager.undefine_virtual_machine(l_vm_id);

  end undefine_virtual_machine;

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

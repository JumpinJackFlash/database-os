create or replace
package body restapi as

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

  function get_vm_seed_images
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_object_type                     varchar2(5) := db_twig.get_string_parameter(p_json_parameters, 'objectType');

  begin

    return vm_manager.get_vm_seed_images(icam.extract_session_id(p_json_parameters), l_object_type);

  end get_vm_seed_images;

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

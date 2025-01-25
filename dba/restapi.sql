create or replace
package restapi as

  function get_service_data
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  function get_virtual_machines
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  function get_vm_seed_images
  (
    p_json_parameters                 json_object_t
  )
  return clob;

  procedure start_virtual_machine
  (
    p_json_parameters                 json_object_t
  );

  procedure stop_virtual_machine
  (
    p_json_parameters                 json_object_t
  );

  procedure undefine_virtual_machine
  (
    p_json_parameters                 json_object_t
  );

  procedure validate_session
  (
    p_json_parameters                 json_object_t,
    p_required_authorization_level    middle_tier_map.required_authorization_level%type,
    p_allow_blocked_session           middle_tier_map.allow_blocked_session%type
  );

end restapi;
.
/
show errors package restapi

create or replace
package vm_manager_runtime

as

  function call_api
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 clob
  )
  return clob;

end vm_manager_runtime;
.
/
show errors package vm_manager_runtime

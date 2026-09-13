create or replace
package vm_manager_runtime

as

  function call_api
  (
    p_json_parameters                 clob
  )
  return clob;

end vm_manager_runtime;
.
/
show errors package vm_manager_runtime

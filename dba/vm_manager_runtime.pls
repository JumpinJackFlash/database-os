create or replace
package body vm_manager_runtime as

  AQ_TIMEOUT                          EXCEPTION;
  pragma exception_init(AQ_TIMEOUT, -25228);

  PACKAGE_INVALIDATED                 EXCEPTION;
  pragma exception_init(PACKAGE_INVALIDATED, -4061);

  PACKAGE_DISCARDED                   EXCEPTION;
  pragma exception_init(PACKAGE_DISCARDED, -4068);

  function get_message_for_host_monitor
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  )
  return clob

  is

    rc                                pls_integer;

    l_json_data                       clob;

    l_dequeue_options                 DBMS_AQ.dequeue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_message                         dbos$message_t;
    l_schema_owner                    varchar2(128);

  begin

    select  sys_context('USERENV', 'CURRENT_SCHEMA')
      into  l_schema_owner
      from  dual;

    l_dequeue_options.wait := 60;     -- Seconds
    l_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;
    l_dequeue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_dequeue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_dequeue_options.deq_condition := 'upper(nvl(tab.user_data.host_name,'''||
      p_host_name||''')) = upper('''||p_host_name||''') and tab.user_data.message_type != '||vm_manager.HOST_MONITOR_REPLY_MESSAGE;

    dbms_aq.dequeue(
      queue_name => l_schema_owner||'.'||vm_manager.MESSAGE_QUEUE,
      dequeue_options => l_dequeue_options,
      message_properties => l_message_properties,
      payload => l_message,
      msgid => l_message_handle);

    select  json_object('clientHandle' is l_message.client_handle,
                        'messageType' is l_message.message_type,
                        'messagePayload' is l_message.message_payload)
      into  l_json_data
      from  dual;

    return l_json_data;

  end get_message_for_host_monitor;

  procedure send_message_to_client
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  )

  is

    l_payload                         dbos$message_t := dbos$message_t(p_json_parameters.get_string('clientHandle'), p_host_name,
      vm_manager.HOST_MONITOR_REPLY_MESSAGE, p_json_parameters.to_clob);
    l_enqueue_options                 DBMS_AQ.enqueue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);

  begin

    l_message_properties.expiration := vm_manager.MESSAGE_EXPIRATION;
    l_enqueue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_enqueue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_message_properties.delay := DBMS_AQ.NO_DELAY;

    dbms_aq.enqueue(queue_name => vm_manager.MESSAGE_QUEUE, enqueue_options => l_enqueue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

  end send_message_to_client;

---
---
---

  function call_api
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 clob
  )
  return clob

  as

    l_json_parameters                 json_object_t := json_object_t(p_json_parameters);
    l_entry_point                     varchar2(30) := db_twig.get_string(l_json_parameters, 'entryPoint');
    l_error_id                        api_errors.error_id%type;
    l_json_response                   clob := '{"status": "success"}';

  begin

    case l_entry_point

      when 'getMessageForHostMonitor' then

        l_json_response := get_message_for_host_monitor(p_host_name, l_json_parameters);

      when 'getVirtualMachineDescription' then

        l_json_response := vm_manager.get_virtual_machine_description(l_json_parameters);

      when 'registerVmHost' then

        vm_manager.register_vm_host(p_host_name, l_json_parameters);

      when 'sendMessageToClient' then

        send_message_to_client(p_host_name, l_json_parameters);

      when 'setVmHostOffline' then

        vm_manager.set_vm_host_offline(p_host_name);

      when 'updateLifecycleState' then

        vm_manager.update_lifecycle_state(p_host_name, l_json_parameters);

      when 'updateVMDescription' then

        vm_manager.update_vm_description(l_json_parameters);

      when 'updateVmState' then

        vm_manager.update_vm_state(l_json_parameters);

      when 'validateVmState' then

        vm_manager.validate_vm_state(p_host_name, l_json_parameters);

      else

        null;

    end case;

    return l_json_response;

  exception

  when PACKAGE_INVALIDATED or PACKAGE_DISCARDED or AQ_TIMEOUT then

    raise;

  when others then

    l_error_id := error_logger.log_api_error(p_json_parameters, db_twig.get_service_id(vm_manager.SERVICE_NAME));
    raise;

  end call_api;

end vm_manager_runtime;
/
show errors package body vm_manager

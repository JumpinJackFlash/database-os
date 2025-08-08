create or replace
package body vm_manager as

  PLUGIN_MODULE                       constant varchar2(15) := 'virtualMachines';

  SERVICE_TITLE                       constant varchar2(27) := 'AsterionDB - Database O/S';

  VM_COMPONENTS_KG                    constant varchar2(26) := 'Virtual Machine Components';
  CONTENTS_KW                         constant varchar2(8) := 'Contents';
  VM_SEED_IMAGE                       constant varchar2(13) := 'VM Seed Image';

  ISO_IMAGES                          constant varchar2(10) := 'ISO Images';
  QCOW2_SEED_IMAGES                   constant varchar2(11) := 'QCOW2 Seeds';
  QCOW2_SEED_EXTENSION                constant varchar2(10) := 'qcow2-seed';

  VDISK_FILE_MODE                     constant pls_integer := 600;
  VCDROM_FILE_MODE                    constant pls_integer := 701;
  SUBDIR_FILE_MODE                    constant pls_integer := 705;

  ROOT_USER                           constant varchar2(9) := 'root:root';
  QEMU_USER                           constant varchar2(9) := 'qemu:qemu';

  procedure create_virtual_machine_action
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_boot_device                     varchar2 default 'hd'
  )

  is

    l_json_response                   json_object_t;
    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_object_id                       vault_objects.object_id%type;
    l_dbos_message                    dbos$message_t;
    l_host_name                       vm_hosts.host_name%type;
    l_status                          vm_hosts.status%type;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  virtual_machine_id = p_virtual_machine_id;

    select  host_name, status
      into  l_host_name, l_status
      from  vm_hosts
     where  host_id = l_virtual_machine.host_id;

    if 'online' != l_status then

      raise_application_error(vm_manager.vm_host_offline, vm_manager.vm_host_offline_emsg);

    end if;

    l_json_parameters.put('machineName', l_virtual_machine.machine_name);

    if l_virtual_machine.virtual_disk_id is not null then

      l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_object_id => l_virtual_machine.virtual_disk_id,
        p_gateway_name => l_host_name, p_access_mode => dgbunker_service.READ_WRITE_ACCESS,
        p_linux_file_mode => VDISK_FILE_MODE, p_linux_subdir_mode => SUBDIR_FILE_MODE, p_disable_stream_write => 'Y',
        p_access_limit => dgbunker_service.unlimited_access_operations, p_valid_until => dgbunker_service.NO_EXPIRATION,
        p_file_user_group => ROOT_USER, p_subdir_user_group => ROOT_USER, p_session_id => p_session_id));

      l_json_parameters.put('vDiskFilename', l_json_response.get_string('filename'));
      if 0 != p_virtual_disk_size then

        l_json_parameters.put('vDiskSize', p_virtual_disk_size);
        l_json_parameters.put('sparseDiskAllocation', p_sparse_disk_allocation);

      end if;

    end if;

    if l_virtual_machine.virtual_cdrom_id is not null then

      l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_object_id => l_virtual_machine.virtual_cdrom_id,
        p_access_limit => dgbunker_service.UNLIMITED_ACCESS_OPERATIONS,
        p_valid_until => dgbunker_service.NO_EXPIRATION, p_access_mode => dgbunker_service.READ_ACCESS,
        p_linux_file_mode => VCDROM_FILE_MODE, p_linux_subdir_mode => SUBDIR_FILE_MODE, p_file_user_group => QEMU_USER, p_subdir_user_group => ROOT_USER,
        p_gateway_name => l_host_name, p_session_id => p_session_id));

      l_json_parameters.put('vCdromFilename', l_json_response.get_string('filename'));

    end if;

    l_json_parameters.put('vCpus', l_virtual_machine.vcpu_count);
    l_json_parameters.put('vMemory', l_virtual_machine.virtual_memory);
    l_json_parameters.put('osVariant', l_virtual_machine.os_variant);
    l_json_parameters.put('networkSource', l_virtual_machine.network_source);
    l_json_parameters.put('networkDevice', l_virtual_machine.network_device);
    l_json_parameters.put('persistent', l_virtual_machine.persistent);
    l_json_parameters.put('bootDevice', p_boot_device);

    l_dbos_message := dbos$message_t(dbms_session.unique_session_id, l_host_name, vm_manager.CREATE_VM_MESSAGE, l_json_parameters.to_string);
    send_message_to_host_monitor(l_dbos_message);

    update  virtual_machines
       set  virtual_cdrom_id = null
     where  virtual_machine_id = p_virtual_machine_id;

  end create_virtual_machine_action;

  function get_disks
  (
    p_xml_description                 virtual_machines.xml_description%type
  )
  return json_array_t

  is

    l_json_array                      json_array_t := json_array_t;
    l_xml_doc                         dbms_xmldom.DOMDocument;
    l_xml_element                     dbms_xmldom.DOMElement;
    l_node_list                       dbms_xmldom.DOMNodelist;
    l_node                            dbms_xmldom.DOMNode;
    l_node_name                       varchar2(256);
    l_attributes                      dbms_xmldom.DOMNamedNodeMap;
    l_attribute                       dbms_xmldom.DOMAttr;
    l_node_value                      clob;
    l_length                          pls_integer;

  begin

    l_xml_doc := dbms_xmldom.newDOMDocument(p_xml_description);
    l_xml_element := dbms_xmldom.getDocumentElement(l_xml_doc);

    l_node_list := dbms_xmldom.getElementsByTagName(l_xml_element, 'source');
    l_length := DBMS_XMLDOM.getLength(l_node_list);

    for i in 0 .. l_length - 1 loop

      l_node := dbms_xmldom.item(l_node_list, i);
      l_node_name := dbms_xmldom.getnodename(l_node);
      l_node_value := dbms_xmldom.getnodevalue(l_node);

      l_attributes := dbms_xmldom.getattributes(l_node);
      l_node := dbms_xmldom.getnameditem(l_attributes, 'file');

      if not dbms_xmldom.isnull(l_node) then

        l_attribute := dbms_xmldom.makeattr(l_node);

        l_node_value := dbms_xmldom.getvalue(l_attribute);

        l_json_array.append(l_node_value);

      end if;

    end loop;

    dbms_xmldom.freedocument(l_xml_doc);

    return l_json_array;

  end get_disks;

  function get_disks
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  )
  return json_array_t

  is

    l_xml_description                 virtual_machines.xml_description%type;

  begin

    select  xml_description
      into  l_xml_description
      from  virtual_machines
     where  virtual_machine_id = p_virtual_machine_id;

    return get_disks(l_xml_description);

  end get_disks;

  function get_message_for_client
  (
    p_timeout                         pls_integer default 60
  )
  return json_object_t

  is

    l_rc                              pls_integer;
    l_dequeue_options                 DBMS_AQ.dequeue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_payload                         dbos$message_t;
    l_json_response                   json_object_t := json_object_t;

  begin

    l_dequeue_options.wait := p_timeout;
    l_dequeue_options.navigation := DBMS_AQ.FIRST_MESSAGE;
    l_dequeue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_dequeue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_dequeue_options.deq_condition := 'tab.user_data.client_handle = '''||dbms_session.unique_session_id||''' and tab.user_data.message_type = '||vm_manager.HOST_MONITOR_REPLY_MESSAGE;

    dbms_aq.dequeue(queue_name => vm_manager.MESSAGE_QUEUE, dequeue_options => l_dequeue_options,
      message_properties => l_message_properties, payload => l_payload, msgid => l_message_handle);

    l_json_response.put('hostName', l_payload.host_name);
    l_json_response.put('messageType', l_payload.message_type);
    l_json_response.put('messagePayload', json_object_t(l_payload.message_payload));

    return l_json_response;

  end get_message_for_client;

  procedure send_message_to_host_monitor
  (
    p_message                         dbos$message_t
  )

  as

    l_enqueue_options                 DBMS_AQ.enqueue_options_t;
    l_message_properties              DBMS_AQ.message_properties_t;
    l_message_handle                  raw(16);
    l_schema_owner                    varchar2(128);

  begin

    select  sys_context('USERENV', 'CURRENT_SCHEMA')
      into  l_schema_owner
      from  dual;

    l_message_properties.expiration := MESSAGE_EXPIRATION;
    l_enqueue_options.visibility := DBMS_AQ.IMMEDIATE;
    l_enqueue_options.delivery_mode := DBMS_AQ.BUFFERED;
    l_message_properties.delay := DBMS_AQ.NO_DELAY;

    dbms_aq.enqueue(
      queue_name => l_schema_owner||'.'||vm_manager.MESSAGE_QUEUE,
      enqueue_options => l_enqueue_options,
      message_properties => l_message_properties,
      payload => p_message,
      msgid => l_message_handle);

  end send_message_to_host_monitor;

  function set_obscure_vdisk
  (
    p_xml_description                 virtual_machines.xml_description%type,
    p_disk_number                     pls_integer,
    p_obscure_filename                varchar2
  )
  return virtual_machines.xml_description%type

  is

    l_json_array                      json_array_t := json_array_t;
    l_xml_doc                         dbms_xmldom.DOMDocument;
    l_xml_element                     dbms_xmldom.DOMElement;
    l_node_list                       dbms_xmldom.DOMNodelist;
    l_node                            dbms_xmldom.DOMNode;
    l_node_name                       varchar2(256);
    l_attributes                      dbms_xmldom.DOMNamedNodeMap;
    l_attribute                       dbms_xmldom.DOMAttr;
    l_node_value                      clob;
    l_xml_description                 virtual_machines.xml_description%type;
    l_length                          pls_integer;

  begin

    l_xml_doc := dbms_xmldom.newDOMDocument(p_xml_description);
    l_xml_element := dbms_xmldom.getDocumentElement(l_xml_doc);

    l_node_list := dbms_xmldom.getElementsByTagName(l_xml_element, 'source');
    l_length := DBMS_XMLDOM.getLength(l_node_list);

    l_node := dbms_xmldom.item(l_node_list, p_disk_number);
    l_node_name := dbms_xmldom.getnodename(l_node);
    l_node_value := dbms_xmldom.getnodevalue(l_node);

    l_attributes := dbms_xmldom.getattributes(l_node);
    l_node := dbms_xmldom.getnameditem(l_attributes, 'file');

    if not dbms_xmldom.isnull(l_node) then

      l_attribute := dbms_xmldom.makeattr(l_node);

      dbms_xmldom.setvalue(l_attribute, p_obscure_filename);
      l_node_value := dbms_xmldom.getvalue(l_attribute);

    end if;

    l_xml_description := dbms_xmldom.getxmltype(l_xml_doc);

    dbms_xmldom.freedocument(l_xml_doc);

    return l_xml_description;

  end set_obscure_vdisk;

  procedure validate_lifecycle_state
  (
    p_lifecycle_state                 virtual_machines.lifecycle_state%type,
    p_state_detail                    virtual_machines.state_detail%type,
    p_next_lifecycle_state            virtual_machines.lifecycle_state%type,
    p_next_state_detail               virtual_machines.state_detail%type
  )

  is

  begin

    case p_next_lifecycle_state

      when 'starting' then

        if 'start' = p_lifecycle_state or 'starting' = p_lifecycle_state or 'crashed' = p_lifecycle_state then

          return;

        end if;

      when 'running' then

        if 'starting' = p_lifecycle_state then

          return;

        end if;

      when 'stop' then

        if 'running' = p_lifecycle_state then

          return;

        end if;

      when 'stopping' then

        if 'stop' = p_lifecycle_state then

          return;

        end if;

        if 'running' = p_lifecycle_state and p_next_state_detail in ('guest initiated', 'host initiated') then

          return;

        end if;

      when 'stopped' then

        if 'stopping' = p_lifecycle_state then

          return;

        end if;

      when 'crashed' then

        return;

    end case;

    raise_application_error(-20100, 'Invalid lifecycle transition: '||p_lifecycle_state||' --> '||p_next_lifecycle_state);

  end validate_lifecycle_state;

---
---
---

  function get_cpu_count
  (
    p_host_capabilities               vm_hosts.host_capabilities%type
  )
  return pls_integer

  is

    l_xml_doc                         dbms_xmldom.DOMDocument;
    l_xml_element                     dbms_xmldom.DOMElement;
    l_node_list                       dbms_xmldom.DOMNodelist;
    l_node                            dbms_xmldom.DOMNode;
    l_attributes                      dbms_xmldom.DOMNamedNodeMap;
    l_attribute                       dbms_xmldom.DOMAttr;
    l_cpu_count                       pls_integer;

  begin

    l_xml_doc := dbms_xmldom.newDOMDocument(p_host_capabilities);
    l_xml_element := dbms_xmldom.getDocumentElement(l_xml_doc);

    l_node_list := dbms_xmldom.getElementsByTagName(l_xml_element, 'cpus');
    l_node := dbms_xmldom.item(l_node_list, 0);
    l_attributes := dbms_xmldom.getattributes(l_node);
    l_node := dbms_xmldom.getnameditem(l_attributes, 'num');
    l_attribute := dbms_xmldom.makeattr(l_node);

    l_cpu_count := to_number(dbms_xmldom.getvalue(l_attribute));

    dbms_xmldom.freedocument(l_xml_doc);

    return l_cpu_count;

  end get_cpu_count;

  function get_cpu_count
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return pls_integer

  is

    l_host_capabilities               vm_hosts.host_capabilities%type;

  begin

    select  host_capabilities
      into  l_host_capabilities
      from  vm_hosts
     where  host_id = p_host_id;

    return get_cpu_count(l_host_capabilities);

  end get_cpu_count;

-- This function is dependent upon a specific XML format returned by libvirt....

  function get_installed_memory
  (
    p_host_capabilities               vm_hosts.host_capabilities%type
  )
  return pls_integer

  is

    l_xml_doc                         dbms_xmldom.DOMDocument;
    l_xml_element                     dbms_xmldom.DOMElement;
    l_node_list                       dbms_xmldom.DOMNodelist;
    l_node                            dbms_xmldom.DOMNode;
    l_child                           dbms_xmldom.DOMNode;
    l_installed_memory                pls_integer := 0;

  begin

    l_xml_doc := dbms_xmldom.newDOMDocument(p_host_capabilities);
    l_xml_element := dbms_xmldom.getDocumentElement(l_xml_doc);

    l_node_list := dbms_xmldom.getElementsByTagName(l_xml_element, 'memory');
    l_node := dbms_xmldom.getfirstchild(dbms_xmldom.item(l_node_list, 0));
    l_installed_memory := to_number(dbms_xmldom.getnodevalue(l_node));

    dbms_xmldom.freedocument(l_xml_doc);

    return l_installed_memory;

  end get_installed_memory;

  function get_installed_memory
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return pls_integer

  is

    l_host_capabilities               vm_hosts.host_capabilities%type;

  begin

    select  host_capabilities
      into  l_host_capabilities
      from  vm_hosts
     where  host_id = p_host_id;

    return get_installed_memory(l_host_capabilities);

  end get_installed_memory;

  function get_seed_images
  (
    p_session_id                      varchar2,
    p_object_type_id                  number
  )
  return clob

  is

    l_keyword_and_value               json_object_t := json_object_t;
    l_keywords_and_values             json_array_t := json_array_t;
    l_column_to_return                json_object_t := json_object_t;
    l_columns_to_return               json_array_t := json_array_t;
    l_object_type_ids                 json_array_t := json_array_t;

  begin

--  We're looking for this type of object...

    l_object_type_ids.append(p_object_type_id);

--  We don't need every column...

    l_column_to_return.put('columnName', 'objectId');
    l_column_to_return.put('column', 'object_id');
    l_columns_to_return.append(l_column_to_return);

    l_column_to_return.put('columnName', 'objectName');
    l_column_to_return.put('column', 'object_name');
    l_columns_to_return.append(l_column_to_return);

    l_column_to_return.put('columnName', 'fileExtension');
    l_column_to_return.put('column', 'file_extension');
    l_columns_to_return.append(l_column_to_return);

    l_column_to_return.put('columnName', 'creationDate');
    l_column_to_return.put('column', 'creation_date');
    l_columns_to_return.append(l_column_to_return);

--  We're gonna be getting a bunch of objects that have been cataloged.
--  Specify our keyword group...

    l_keyword_and_value.put('keywordGroup', VM_COMPONENTS_KG);

--  Let's get all of our VM Seed Images

    l_keyword_and_value.put('keyword', CONTENTS_KW);
    l_keyword_and_value.put('keywordValue', VM_SEED_IMAGE);
    l_keywords_and_values.append(l_keyword_and_value);

    return dgbunker_service.get_vault_objects(p_session_id => p_session_id, p_view_type => dgbunker_service.OVT_CATALOGED,
      p_selected_keywords_and_values => l_keywords_and_values, p_object_type_ids => l_object_type_ids,
      p_columns_to_return => l_columns_to_return);

  end get_seed_images;

---
---
---

  function create_cloud_init_cdrom_image
  (
    p_session_id                      varchar2,
    p_host_name                       vm_hosts.host_name%type,
    p_machine_name                    virtual_machines.machine_name%type,
    p_meta_data                       clob,
    p_user_data                       clob,
    p_network_config                  clob
  )
  return vault_objects.object_id%type

  is

    l_meta_data_id                    vault_objects.object_id%type;
    l_user_data_id                    vault_objects.object_id%type;
    l_net_data_id                     vault_objects.object_id%type;
    l_cdrom_id                        vault_objects.object_id%type;

    l_meta_data_filename              varchar2(256);
    l_user_data_filename              varchar2(256);
    l_net_data_filename               varchar2(256);
    l_cdrom_filename                  varchar2(256);

    l_clob                            clob;

    l_json_response                   json_object_t;
    l_message_payload                 json_object_t;
    l_json_parameters                 json_object_t := json_object_t;
    l_dbos_message                    dbos$message_t;

  begin

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'meta-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_cloud_init_cdrom_image'));
    l_meta_data_id := l_json_response.get_string('objectId');

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'user-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_cloud_init_cdrom_image'));
    l_user_data_id := l_json_response.get_string('objectId');

    if p_network_config is not null then

      l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'network-data.txt',
          p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_cloud_init_cdrom_image'));
      l_net_data_id := l_json_response.get_string('objectId');

    end if;

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => p_machine_name||'.iso',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_cloud_init_cdrom_image'));
    l_cdrom_id := l_json_response.get_string('objectId');

    commit;

    l_clob := dgbunker_service.get_clob_locator(p_object_id => l_meta_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_clob_value(l_meta_data_id, p_meta_data);
    dgbunker_service.release_clob_locator(p_object_id => l_meta_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    l_clob := dgbunker_service.get_clob_locator(p_object_id => l_user_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_clob_value(l_user_data_id, p_user_data);
    dgbunker_service.release_clob_locator(p_object_id => l_user_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    if p_network_config is not null then

      l_clob := dgbunker_service.get_clob_locator(p_object_id => l_net_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
      dgbunker_service.set_clob_value(l_net_data_id, p_network_config);
      dgbunker_service.release_clob_locator(p_object_id => l_net_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    end if;

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_meta_data_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
    l_meta_data_filename := l_json_response.get_string('filename');
    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_user_data_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
    l_user_data_filename := l_json_response.get_string('filename');

    if p_network_config is not null then

      l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_net_data_id,
          p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
      l_net_data_filename := l_json_response.get_string('filename');

    end if;

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_cdrom_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.WRITE_ACCESS));
    l_cdrom_filename := l_json_response.get_string('filename');

    commit;

    l_json_parameters.put('metaDataFilename', l_meta_data_filename);
    l_json_parameters.put('userDataFilename', l_user_data_filename);

    if p_network_config is not null then

      l_json_parameters.put('netDataFilename', l_net_data_filename);

    end if;

    l_json_parameters.put('vCdromFilename', l_cdrom_filename);

    l_dbos_message := dbos$message_t(dbms_session.unique_session_id, p_host_name, vm_manager.CREATE_CLOUD_INIT_CDROM_MESSAGE, l_json_parameters.to_string);
    send_message_to_host_monitor(l_dbos_message);

    l_json_response := get_message_for_client;
    l_message_payload := l_json_response.get_object('messagePayload');

    if 'success' != l_message_payload.get_string('status') then

      raise_application_error(-20000, l_message_payload.to_clob);

    end if;

    return l_cdrom_id;

  end create_cloud_init_cdrom_image;

  function create_cloud_init_cdrom_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_host_name                       vm_hosts.host_name%type,
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
  return vault_objects.object_id%type

  is

    l_content                         clob;

    l_meta_data_id                    vault_objects.object_id%type;
    l_user_data_id                    vault_objects.object_id%type;
    l_net_data_id                     vault_objects.object_id%type;
    l_cdrom_id                        vault_objects.object_id%type;

    l_meta_data_filename              varchar2(256);
    l_user_data_filename              varchar2(256);
    l_net_data_filename               varchar2(256);
    l_cdrom_filename                  varchar2(256);

    l_clob                            clob;

    l_json_response                   json_object_t;
    l_message_payload                 json_object_t;
    l_json_parameters                 json_object_t := json_object_t;
    l_dbos_message                    dbos$message_t;

  begin

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'meta-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager'));
    l_meta_data_id := l_json_response.get_string('objectId');

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'user-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager'));
    l_user_data_id := l_json_response.get_string('objectId');

    if p_ip4_address is not null then

      l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => 'network-data.txt',
          p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager'));
      l_net_data_id := l_json_response.get_string('objectId');

    end if;

    l_json_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => p_machine_name||'.iso',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager'));
    l_cdrom_id := l_json_response.get_string('objectId');

    commit;

    l_content := 'instance-id: '||p_machine_name||chr(10)||
                 'local-hostname: '||p_local_hostname;

    l_clob := dgbunker_service.get_clob_locator(p_object_id => l_meta_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_clob_value(l_meta_data_id, l_content);
    dgbunker_service.release_clob_locator(p_object_id => l_meta_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    l_content := '#cloud-config'||chr(10);
    if p_password is not null then

      l_content := l_content||'password: '||p_password||chr(10);

    end if;

    l_content:= l_content||'chpasswd: { expire: True }'||chr(10)||
      'ssh_pwauth: True'||chr(10)||
      'user: {name: '||p_user||'}'||chr(10);

    if p_authorized_ssh_keys.get_size != 0 then

      l_content := l_content||'ssh_authorized_keys: '||chr(10);

      for x in 0 .. p_authorized_ssh_keys.get_size - 1 loop

        l_json_response := treat(p_authorized_ssh_keys.get(x) as json_object_t);
        l_content := l_content||'  - '||l_json_response.get_string('sshKey')||chr(10);

      end loop;

    end if;

    l_clob := dgbunker_service.get_clob_locator(p_object_id => l_user_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_clob_value(l_user_data_id, l_content);
    dgbunker_service.release_clob_locator(p_object_id => l_user_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    if p_ip4_address is not null then

      l_content := 'version: 1'||chr(10)||
        'config:'||chr(10)||
        '  - type: physical'||chr(10)||
        '    name: eth0'||chr(10)||
        '    subnets:'||chr(10)||
        '      - type: static'||chr(10)||
        '        control: auto'||chr(10)||
        '        address: '||p_ip4_address||chr(10)||
        '        gateway: '||p_ip4_gateway||chr(10)||
        '        netmask: '||p_ip4_netmask||chr(10)||
        '        dns_nameservers:'||chr(10);

      for x in 0 .. p_dns_nameservers.get_size - 1 loop

        l_json_response := treat(p_dns_nameservers.get(x) as json_object_t);
        l_content := l_content||'          - '||l_json_response.get_string('nameserver')||chr(10);

      end loop;

      if p_dns_search is not null and '' != p_dns_search then

        l_content := l_content||'        dns_search:'||chr(10)||'          - '||p_dns_search||chr(10);

      end if;

      l_clob := dgbunker_service.get_clob_locator(p_object_id => l_net_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);
      dgbunker_service.set_clob_value(l_net_data_id, l_content);
      dgbunker_service.release_clob_locator(p_object_id => l_net_data_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    end if;

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_meta_data_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
    l_meta_data_filename := l_json_response.get_string('filename');

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_user_data_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
    l_user_data_filename := l_json_response.get_string('filename');

    if p_ip4_address is not null then

      l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_net_data_id,
          p_gateway_name => p_host_name, p_access_mode => dgbunker_service.READ_ACCESS));
      l_net_data_filename := l_json_response.get_string('filename');

    end if;

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_session_id => p_session_id, p_object_id => l_cdrom_id,
        p_gateway_name => p_host_name, p_access_mode => dgbunker_service.WRITE_ACCESS));
   l_cdrom_filename := l_json_response.get_string('filename');

    commit;

    l_json_parameters.put('metaDataFilename', l_meta_data_filename);
    l_json_parameters.put('userDataFilename', l_user_data_filename);
    if p_ip4_address is not null then

      l_json_parameters.put('netDataFilename', l_net_data_filename);

    end if;

    l_json_parameters.put('vCdromFilename', l_cdrom_filename);

    l_dbos_message := dbos$message_t(dbms_session.unique_session_id, p_host_name, vm_manager.CREATE_CLOUD_INIT_CDROM_MESSAGE, l_json_parameters.to_string);
    send_message_to_host_monitor(l_dbos_message);

    l_json_response := get_message_for_client;
    l_message_payload := l_json_response.get_object('messagePayload');

    if 'success' != l_message_payload.get_string('status') then

      raise_application_error(-20000, l_message_payload.to_clob);

    end if;

    return l_cdrom_id;

  end create_cloud_init_cdrom_image;

  procedure create_dbos_service

  is

  begin

    db_twig.create_dbtwig_service(p_service_name => SERVICE_NAME, p_service_owner => sys_context('USERENV', 'CURRENT_USER'),
      p_session_validation_procedure => 'restapi.validate_session');

  end create_dbos_service;

  procedure create_seed_from_virtual_disk
  (
    p_session_id                      varchar2,
    p_seed_image_name                 varchar2,
    p_virtual_disk_id                 virtual_machines.virtual_disk_id%type
  )

  is

    l_dest_object_id                  vault_objects.object_id%type;

    l_response                        json_object_t;

    l_source_blob                     blob;
    l_dest_blob                       blob;

  begin

    l_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => p_seed_image_name||'.'||QCOW2_SEED_EXTENSION,
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_seed_from_virtual_disk'));
    l_dest_object_id := l_response.get_string('objectId');

    commit;

    l_source_blob := dgbunker_service.get_blob_locator(p_object_id => p_virtual_disk_id);

    l_dest_blob := dgbunker_service.get_blob_locator(p_object_id => l_dest_object_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_blob_value(l_dest_object_id, l_source_blob);
    dgbunker_service.release_blob_locator(p_object_id => l_dest_object_id, p_for_update => dgbunker_service.OPTION_ENABLED);

  end create_seed_from_virtual_disk;

  function create_virtual_disk_from_seed
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2,
    p_seed_image_id                   vault_objects.object_id%type
  )
  return vault_objects.object_id%type

  is

    l_dest_object_id                  vault_objects.object_id%type;

    l_response                        json_object_t;

    l_source_blob                     blob;
    l_dest_blob                       blob;

  begin

    l_response := json_object_t(dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => p_disk_image_name,
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_virtual_disk_from_seed'));
    l_dest_object_id := l_response.get_string('objectId');

    commit;

    l_source_blob := dgbunker_service.get_blob_locator(p_object_id => p_seed_image_id);

    l_dest_blob := dgbunker_service.get_blob_locator(p_object_id => l_dest_object_id, p_for_update => dgbunker_service.OPTION_ENABLED);
    dgbunker_service.set_blob_value(l_dest_object_id, l_source_blob);
    dgbunker_service.release_blob_locator(p_object_id => l_dest_object_id, p_for_update => dgbunker_service.OPTION_ENABLED);

    return l_dest_object_id;

  end create_virtual_disk_from_seed;

  function create_boot_disk
  (
    p_session_id                      varchar2,
    p_disk_image_name                 varchar2
  )
  return clob

  is

  begin

    return dgbunker_service.create_an_object(p_session_id => p_session_id, p_source_path => p_disk_image_name,
      p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager.create_boot_disk');

  end create_boot_disk;

  procedure create_vm_from_iso_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_iso_image_id                    virtual_machines.virtual_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_host_id                         vm_hosts.host_id%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  )

  is

    l_result                          json_object_t;
    l_virtual_machine_id              virtual_machines.virtual_machine_id%type;
    l_network_source                  virtual_machines.network_source%type := 'network';
    l_object_id                       vault_objects.object_id%type;
    l_variant                         os_variants.variant%type;

  begin

    if 'Y' = p_bridged_connection then

      l_network_source := 'bridge';

    end if;

    select  variant
      into  l_variant
      from  os_variants
     where  variant_id = p_os_variant_id;

    l_result := json_object_t(create_boot_disk(p_session_id, p_machine_name||'.qcow2'));
    l_object_id := l_result.get_string('objectId');

    insert into virtual_machines
      (virtual_machine_id, machine_name, virtual_disk_id, virtual_cdrom_id, vcpu_count, virtual_memory, os_variant,
       network_source, network_device, host_id, lifecycle_state, save_xml_description)
    values
      (id_seq.nextval, p_machine_name, l_object_id, p_iso_image_id, p_vcpu_count, p_virtual_memory * 1024,
       l_variant, l_network_source, p_network_device, p_host_id, 'start', 'N')
    returning virtual_machine_id into l_virtual_machine_id;

    create_virtual_machine_action(p_session_id => p_session_id, p_virtual_machine_id => l_virtual_machine_id, p_virtual_disk_size => p_virtual_disk_size,
      p_sparse_disk_allocation => p_sparse_disk_allocation, p_boot_device => 'cdrom');

  end create_vm_from_iso_image;

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.virtual_disk_id%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_host_id                         vm_hosts.host_id%type,
    p_meta_data                       clob,
    p_user_data                       clob,
    p_network_config                  clob,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  )

  is

    l_result                          json_object_t;
    l_virtual_machine_id              virtual_machines.virtual_machine_id%type;
    l_network_source                  virtual_machines.network_source%type := 'network';
    l_cdrom_id                        vault_objects.object_id%type;
    l_vdisk_id                        vault_objects.object_id%type;
    l_variant                         os_variants.variant%type;
    l_host_name                       vm_hosts.host_name%type;
    l_status                          vm_hosts.status%type;

  begin

    select  host_name, status
      into  l_host_name, l_status
      from  vm_hosts
     where  host_id = p_host_id;

    if 'online' != l_status then

      raise_application_error(vm_manager.vm_host_offline, vm_manager.vm_host_offline_emsg);

    end if;

    if 'Y' = p_bridged_connection then

      l_network_source := 'bridge';

    end if;

    select  variant
      into  l_variant
      from  os_variants
     where  variant_id = p_os_variant_id;

    l_cdrom_id := create_cloud_init_cdrom_image(p_session_id, p_machine_name, l_host_name, p_meta_data, p_user_data, p_network_config);
    l_vdisk_id := create_virtual_disk_from_seed(p_session_id, p_machine_name||'.qcow2', p_seed_image_id);

    insert into virtual_machines
      (virtual_machine_id, machine_name, virtual_disk_id, virtual_cdrom_id, vcpu_count, virtual_memory, os_variant,
       network_source, network_device, host_id, lifecycle_state)
    values
      (id_seq.nextval, p_machine_name, l_vdisk_id, l_cdrom_id, p_vcpu_count, p_virtual_memory * 1024,
       l_variant, l_network_source, p_network_device, p_host_id, 'start')
    returning virtual_machine_id into l_virtual_machine_id;

    create_virtual_machine_action(p_session_id => p_session_id, p_virtual_machine_id => l_virtual_machine_id, p_boot_device => 'hd');

  end create_vm_from_qcow_image;

  procedure create_vm_from_qcow_image
  (
    p_session_id                      varchar2,
    p_machine_name                    virtual_machines.machine_name%type,
    p_seed_image_id                   virtual_machines.virtual_disk_id%type,
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
    p_network_device                  virtual_machines.network_device%type default 'default'
  )

  is

    l_result                          json_object_t;
    l_virtual_machine_id              virtual_machines.virtual_machine_id%type;
    l_network_source                  virtual_machines.network_source%type := 'network';
    l_cdrom_id                        vault_objects.object_id%type;
    l_vdisk_id                        vault_objects.object_id%type;
    l_variant                         os_variants.variant%type;
    l_host_name                       vm_hosts.host_name%type;
    l_status                          vm_hosts.status%type;

  begin

    select  host_name, status
      into  l_host_name, l_status
      from  vm_hosts
     where  host_id = p_host_id;

    if 'online' != l_status then

      raise_application_error(vm_manager.vm_host_offline, vm_manager.vm_host_offline_emsg);

    end if;

    if 'Y' = p_bridged_connection then

      l_network_source := 'bridge';

    end if;

    select  variant
      into  l_variant
      from  os_variants
     where  variant_id = p_os_variant_id;

    l_cdrom_id := create_cloud_init_cdrom_image(p_session_id, p_machine_name, l_host_name, p_local_hostname, p_user, p_password, p_ssh_keys,
      p_ip4_address, p_ip4_gateway, p_ip4_netmask, p_nameservers, p_dns_search);
    l_vdisk_id := create_virtual_disk_from_seed(p_session_id, p_machine_name||'.qcow2', p_seed_image_id);

    insert into virtual_machines
      (virtual_machine_id, machine_name, virtual_disk_id, virtual_cdrom_id, vcpu_count, virtual_memory, os_variant,
       network_source, network_device, host_id, lifecycle_state)
    values
      (id_seq.nextval, p_machine_name, l_vdisk_id, l_cdrom_id, p_vcpu_count, p_virtual_memory * 1024,
       l_variant, l_network_source, p_network_device, p_host_id, 'start')
    returning virtual_machine_id into l_virtual_machine_id;

    create_virtual_machine_action(p_session_id => p_session_id, p_virtual_machine_id => l_virtual_machine_id, p_boot_device => 'hd');

  end create_vm_from_qcow_image;

  procedure delete_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_delete_boot_disk                boolean
  )

  is

    l_virtual_disk_id                 virtual_machines.virtual_disk_id%type;
    l_json_array                      json_array_t := json_array_t;

  begin

    if p_delete_boot_disk then

      select  virtual_disk_id
        into  l_virtual_disk_id
        from  virtual_machines
       where  virtual_machine_id = p_virtual_machine_id;

      if l_virtual_disk_id is not null then

        l_json_array.append(l_virtual_disk_id);
        dgbunker_service.delete_objects(p_session_id, l_json_array);

      end if;

    end if;

    delete
      from  virtual_machines
     where  virtual_machine_id = p_virtual_machine_id;

  end delete_virtual_machine;

  function get_iso_seed_images
  (
    p_session_id                      varchar2
  )
  return clob

  is

    l_json_object                     json_object_t;

  begin

--  We're looking for these types of objects...

    l_json_object := json_object_t(dgbunker_service.get_object_type_id(ISO_IMAGES));
    return get_seed_images(p_session_id, l_json_object.get_number('objectTypeId'));

  end get_iso_seed_images;

  function get_os_variants return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  json_object('osVariants' is json_arrayagg(
              json_object('variantId' is variant_id,
                          'longName' is long_name) order by long_name returning clob) returning clob),
            count(*)
      into  l_result, l_rows
      from  os_variants;

    if 0 = l_rows then

      return db_twig.empty_json_array('osVariants');

    end if;

    return l_result;

  end get_os_variants;

  function get_qcow2_seed_images
  (
    p_session_id                      varchar2
  )
  return clob

  is

    l_json_object                     json_object_t;

  begin

    l_json_object := json_object_t(dgbunker_service.get_object_type_id(QCOW2_SEED_IMAGES));
    return get_seed_images(p_session_id, l_json_object.get_number('objectTypeId'));

  end get_qcow2_seed_images;

  function get_service_data return clob

  is

    l_service_data                    json_object_t := json_object_t(db_twig.get_service_data(SERVICE_NAME));

  begin

    l_service_data.put('serviceTitle', SERVICE_TITLE);
    l_service_data.put('serviceName', SERVICE_NAME);
    return l_service_data.to_clob;

  end get_service_data;

  function get_virtual_machine_description
  (
    p_json_parameters                 json_object_t
  )
  return clob

  is

    l_virtual_machine_id              virtual_machines.virtual_machine_id%type := db_twig.get_number(p_json_parameters, 'virtualMachineId');
    l_xml_description                 virtual_machines.xml_description%type;

  begin

    select  xml_description
      into  l_xml_description
      from  virtual_machines
     where  virtual_machine_id = l_virtual_machine_id;

    return l_xml_description.getclobval;

  end get_virtual_machine_description;

  function get_virtual_machines return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  count(*), json_object('virtualMachines' is json_arrayagg(
                        json_object(
                          'virtualMachineId'  is virtual_machine_id,
                          'creationTimestamp'   is db_twig.convert_timestamp_to_unix_timestamp(creation_timestamp),
                          'machineName'         is machine_name,
                          'status'              is lifecycle_state,
                          'statusDetail'        is state_detail,
                          'virtualDiskId'       is virtual_disk_id,
                          'virtualCdromId'      is virtual_cdrom_id,
                          'vCpuCount'           is vcpu_count,
                          'virtualMemory'       is virtual_memory,
                          'osVariant'           is os_variant,
                          'networkSource'       is network_source,
                          'networkDevice'       is network_device,
                          'uuid'                is uuid,
                          'interfaces'          is interfaces,
                          'persistent'          is persistent,
                          'saveXmlDescription'  is save_xml_description,
                          'host'                is vm_manager.get_vm_host_name(host_id)) order by machine_name returning clob) returning clob)
      into  l_rows, l_result
      from  virtual_machines;

      if 0 = l_rows then

        return db_twig.empty_json_array('virtualMachines');

      end if;

      return l_result;

  end get_virtual_machines;

  function get_vm_hosts return clob

  is

    l_result                          clob;
    l_rows                            pls_integer;

  begin

    select  count(*), json_object('vmHosts' is json_arrayagg(json_object(
              'hostId'            is host_id,
              'hostName'          is host_name,
              'status'            is status,
              'lastUpdate'        is db_twig.convert_timestamp_to_unix_timestamp(last_update),
              'installedMemory'   is get_installed_memory(host_capabilities),
              'cpuCount'          is get_cpu_count(host_capabilities),
              'hypervisorVersion' is hypervisor_version,
              'libvirtVersion'    is libvirt_version,
              'machineType'       is machine_type,
              'osRelease'         is os_release) order by host_name returning clob) returning clob)
      into  l_rows, l_result
      from  vm_hosts;

    if 0 = l_rows then

      return db_twig.empty_json_array('vmHosts');

    end if;

    return l_result;

  end get_vm_hosts;

  function get_vm_host_name
  (
    p_host_id                         vm_hosts.host_id%type
  )
  return vm_hosts.host_name%type

  is

    l_host_name                       vm_hosts.host_name%type;

  begin

    select  host_name
      into  l_host_name
      from  vm_hosts
     where  host_id = p_host_id;

    return l_host_name;

  exception

  when no_data_found then

    return null;

  end get_vm_host_name;

  procedure import_virtual_machine
  (
    p_object_id                       vault_objects.object_id%type,
    p_machine_name                    virtual_machines.machine_name%type,
    p_os_variant_id                   os_variants.variant_id%type,
    p_vcpu_count                      virtual_machines.vcpu_count%type default 1,
    p_virtual_memory                  virtual_machines.virtual_memory%type default 1024,
    p_bridged_connection              varchar2 default 'N',
    p_network_device                  virtual_machines.network_device%type default 'default'
  )

  is

    l_variant                         os_variants.variant%type;
    l_network_source                  virtual_machines.network_source%type := 'network';

  begin

    if 'Y' = p_bridged_connection then

      l_network_source := 'bridge';

    end if;

    select  variant
      into  l_variant
      from  os_variants
     where  variant_id = p_os_variant_id;

    insert into virtual_machines
      (virtual_machine_id, machine_name, virtual_disk_id, vcpu_count, virtual_memory, network_source, network_device, os_variant)
    values
      (id_seq.nextval, p_machine_name, p_object_id, p_vcpu_count, p_virtual_memory, l_network_source, p_network_device,
       l_variant);

  end import_virtual_machine;

  procedure register_vm_host
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  )

  is

    l_sysinfo                         clob := db_twig.get_clob(p_json_parameters, 'sysInfo');
    l_host_capabilities               clob := db_twig.get_clob(p_json_parameters, 'hostCapabilities');
    l_hypervisor_version              vm_hosts.hypervisor_version%type := db_twig.get_number(p_json_parameters, 'hypervisorVersion');
    l_libvirt_version                 vm_hosts.libvirt_version%type := db_twig.get_number(p_json_parameters, 'libvirtVersion');
    l_os_release                      vm_hosts.os_release%type := db_twig.get_string(p_json_parameters, 'osRelease');
    l_machine_type                    vm_hosts.machine_type%type := db_twig.get_string(p_json_parameters, 'machineType');

  begin

    insert into vm_hosts
      (host_id, host_name, status, last_update, sysinfo, host_capabilities, hypervisor_version, libvirt_version,
       os_release, machine_type)
    values
      (id_seq.nextval, p_host_name, 'online', systimestamp at time zone 'utc', xmltype(l_sysinfo), xmltype(l_host_capabilities),
       l_hypervisor_version, l_libvirt_version, l_os_release, l_machine_type);

  exception

  when dup_val_on_index then

    update  vm_hosts
       set  status = 'online',
            sysinfo = xmltype(l_sysinfo),
            last_update = systimestamp at time zone 'utc',
            host_capabilities = xmltype(l_host_capabilities),
            hypervisor_version = l_hypervisor_version,
            libvirt_version = l_libvirt_version,
            os_release = l_os_release,
            machine_type = l_machine_type
     where  host_name = p_host_name;

  end register_vm_host;

  procedure set_persistent
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_persistent                      virtual_machines.persistent%type
  )

  is

    l_dbos_message                    dbos$message_t;
    l_host_name                       vm_hosts.host_name%type;
    l_machine_name                    virtual_machines.machine_name%type;
    l_lifecycle_state                 virtual_machines.lifecycle_state%type;
    l_json_parameters                 json_object_t := json_object_t;

  begin

    select  machine_name, host_name, lifecycle_state
      into  l_machine_name, l_host_name, l_lifecycle_state
      from  vm_hosts h, virtual_machines m
     where  virtual_machine_id = p_virtual_machine_id
       and  h.host_id = m.host_id;

    update  virtual_machines
       set  persistent = p_persistent
     where  virtual_machine_id = p_virtual_machine_id;

    if 'running' = l_lifecycle_state and 'N' = p_persistent then

      l_json_parameters.put('machineName', l_machine_name);
      l_dbos_message := dbos$message_t(dbms_session.unique_session_id, l_host_name, vm_manager.UNDEFINE_VM_MESSAGE, l_json_parameters.to_string);
      send_message_to_host_monitor(l_dbos_message);

    end if;

  end set_persistent;

  procedure set_save_xml_description
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_save_xml_description            virtual_machines.save_xml_description%type
  )

  is

  begin

    update  virtual_machines
       set  save_xml_description = p_save_xml_description
     where  virtual_machine_id = p_virtual_machine_id;

  end set_save_xml_description;

  procedure set_vm_host_offline
  (
    p_host_name                       vm_hosts.host_name%type
  )

  is

  begin

    update  vm_hosts
       set  status = 'offline',
            last_update = systimestamp at time zone 'utc'
     where  host_name = p_host_name;

  end set_vm_host_offline;

  procedure start_virtual_machine
  (
    p_session_id                      varchar2,
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type,
    p_boot_device                     varchar2 default 'hd'
  )

  is

    l_json_response                   json_object_t;
    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_object_id                       vault_objects.object_id%type;
    l_dbos_message                    dbos$message_t;
    l_host_name                       vm_hosts.host_name%type;
    l_status                          vm_hosts.status%type;
    l_xml_description                 virtual_machines.xml_description%type;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  virtual_machine_id = p_virtual_machine_id;

    select  host_name, status
      into  l_host_name, l_status
      from  vm_hosts
     where  host_id = l_virtual_machine.host_id;

    if 'online' != l_status then

      raise_application_error(vm_manager.vm_host_offline, vm_manager.vm_host_offline_emsg);

    end if;

    if l_virtual_machine.xml_description is null then

      update  virtual_machines
         set  lifecycle_state = 'start'
       where  virtual_machine_id = p_virtual_machine_id;

      create_virtual_machine_action(p_session_id, p_virtual_machine_id);
      return;

    end if;

    l_json_response := json_object_t(dgbunker_service.generate_object_filename(p_object_id => l_virtual_machine.virtual_disk_id,
      p_gateway_name => l_host_name, p_access_mode => dgbunker_service.READ_WRITE_ACCESS,
      p_linux_file_mode => VDISK_FILE_MODE, p_linux_subdir_mode => SUBDIR_FILE_MODE, p_disable_stream_write => 'Y',
      p_access_limit => dgbunker_service.unlimited_access_operations, p_valid_until => dgbunker_service.NO_EXPIRATION,
      p_file_user_group => ROOT_USER, p_subdir_user_group => ROOT_USER, p_session_id => p_session_id));

    l_xml_description := set_obscure_vdisk(l_virtual_machine.xml_description, 0, l_json_response.get_string('filename'));

    update  virtual_machines
       set  lifecycle_state = 'start',
            xml_description = l_xml_description
     where  virtual_machine_id = p_virtual_machine_id;

    l_json_parameters.put('virtualMachineId', p_virtual_machine_id);
    l_json_parameters.put('machineName', l_virtual_machine.machine_name);
    l_json_parameters.put('xmlDescriptionLength', dbms_lob.getlength(l_xml_description.getclobval));
    l_json_parameters.put('persistent', l_virtual_machine.persistent);

    l_dbos_message := dbos$message_t(dbms_session.unique_session_id, l_host_name, vm_manager.START_VM_MESSAGE, l_json_parameters.to_string);
    send_message_to_host_monitor(l_dbos_message);

  end start_virtual_machine;

  procedure stop_virtual_machine
  (
    p_virtual_machine_id              virtual_machines.virtual_machine_id%type
  )

  is

    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_host_name                       vm_hosts.host_name%type;
    l_status                          vm_hosts.status%type;
    l_dbos_message                    dbos$message_t;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  virtual_machine_id = p_virtual_machine_id;

    update  virtual_machines
       set  lifecycle_state = 'stop'
     where  virtual_machine_id = p_virtual_machine_id;

    select  host_name, status
      into  l_host_name, l_status
      from  vm_hosts
     where  host_id = l_virtual_machine.host_id;

    if 'online' != l_status then

      raise_application_error(vm_manager.vm_host_offline, vm_manager.vm_host_offline_emsg);

    end if;

    l_json_parameters.put('machineName', l_virtual_machine.machine_name);
    l_json_parameters.put('virtualMachineId', p_virtual_machine_id);

    l_dbos_message := dbos$message_t(dbms_session.unique_session_id, l_host_name, vm_manager.STOP_VM_MESSAGE, l_json_parameters.to_string);
    send_message_to_host_monitor(l_dbos_message);

  end stop_virtual_machine;

  procedure update_lifecycle_state
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_lifecycle_state                 virtual_machines.lifecycle_state%type := db_twig.get_string(p_json_parameters, 'lifecycleState');
    l_state_detail                    virtual_machines.state_detail%type := db_twig.get_string(p_json_parameters, 'detail');
    l_disks                           json_array_t;
    l_dbos_message                    dbos$message_t;

    l_json_parameters                 json_object_t := json_object_t;
    l_virtual_machine                 virtual_machines%rowtype;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  machine_name = l_machine_name;

    validate_lifecycle_state(l_virtual_machine.lifecycle_state, l_virtual_machine.state_detail, l_lifecycle_state, l_state_detail);

    update  virtual_machines
       set  lifecycle_state = l_lifecycle_state,
            state_detail = l_state_detail
     where  machine_name = l_machine_name;

    if 'stopped' = l_lifecycle_state then

      l_disks := get_disks(l_virtual_machine.xml_description);

      for i in 0 .. l_disks.get_size - 1 loop

        dgbunker_service.invalidate_obscure_filename(l_disks.get_string(i));

        l_json_parameters.put('storagePool', dgbunker_service.extract_group_key(l_disks.get_string(i)));
        l_dbos_message := dbos$message_t(dbms_session.unique_session_id, p_host_name, vm_manager.DELETE_STORAGE_POOL_MESSAGE,
          l_json_parameters.to_string);
        send_message_to_host_monitor(l_dbos_message);

      end loop;

    end if;

  end update_lifecycle_state;

  procedure update_vm_description
  (
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_xml_description                 clob := db_twig.get_clob(p_json_parameters, 'xmlDescription');

  begin

    update  virtual_machines
       set  xml_description = xmltype(l_xml_description)
     where  machine_name = l_machine_name
       and  save_xml_description = 'Y';

  end update_vm_description;

  procedure update_vm_state
  (
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_uuid                            virtual_machines.uuid%type := db_twig.get_string(p_json_parameters, 'uuid');
    l_persistent                      virtual_machines.persistent%type := db_twig.get_string(p_json_parameters, 'persistent');
    l_interfaces_array                json_array_t := db_twig.get_array(p_json_parameters, 'interfaces');
    l_interfaces                      virtual_machines.interfaces%type := l_interfaces_array.to_clob;
    l_lifecycle_state                 virtual_machines.lifecycle_state%type := db_twig.get_string(p_json_parameters, 'lifecycleState');

  begin

    update  virtual_machines
       set  uuid = l_uuid,
            persistent = l_persistent,
            interfaces = l_interfaces,
            lifecycle_state = l_lifecycle_state
    where   machine_name = l_machine_name;

  end update_vm_state;

  procedure validate_vm_state
  (
    p_host_name                       vm_hosts.host_name%type,
    p_json_parameters                 json_object_t
  )

  is

    l_machine_name                    virtual_machines.machine_name%type := db_twig.get_string(p_json_parameters, 'machineName');
    l_uuid                            virtual_machines.uuid%type := db_twig.get_string(p_json_parameters, 'uuid');
    l_persistent                      virtual_machines.persistent%type := db_twig.get_string(p_json_parameters, 'persistent');
    l_interfaces                      json_array_t := db_twig.get_array(p_json_parameters, 'interfaces');
    l_lifecycle_state                 virtual_machines.lifecycle_state%type := db_twig.get_string(p_json_parameters, 'lifecycleState');
    l_virtual_machine                 virtual_machines%rowtype;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  machine_name = l_machine_name;

    if l_virtual_machine.uuid != l_uuid or
       l_virtual_machine.persistent != l_persistent or
       l_virtual_machine.interfaces != l_interfaces.to_string or
       l_virtual_machine.lifecycle_state != l_lifecycle_state then

      raise_application_error(vm_manager.VM_STATE_MISMATCH, vm_manager.VM_STATE_MISMATCH_EMSG);

    end if;

  exception

  when no_data_found then

    raise_application_error(vm_manager.UNAUTHORIZED_VM_DETECTED, vm_manager.UNAUTHORIZED_VM_DETECTED_EMSG||' - '||p_host_name||':'||l_machine_name);

  end validate_vm_state;

end vm_manager;
/
show errors package body vm_manager

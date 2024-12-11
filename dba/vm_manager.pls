create or replace
package body vm_manager as

  PLUGIN_MODULE                       constant plugin_modules.plugin_module%type := 'virtualMachines';
  s_plugin_process                    json_object_t;

  procedure start_virtual_machine_action
  (
    p_vm_id                           virtual_machines.vm_id%type,
    p_virtual_disk_size               number default 0,
    p_sparse_disk_allocation          varchar2 default 'Y',
    p_boot_device                     varchar2 default 'hd',
    p_remove_cdrom_after_first_boot   varchar2 default 'Y',
    p_first_boot                      varchar2 default 'N'
  )

  is

    l_json_response                   json_object_t;
    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_virtual_disk_filename           varchar2(256) := 'null';
    l_virtual_cdrom_filename          varchar2(256) := 'null';
    l_item_id                         object_versions.item_id%type;
    l_object_created                  vault_objects.object_created%type;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  vm_id = p_vm_id;

    select  object_created
      into  l_object_created
      from  vault_objects
     where  object_id = l_virtual_machine.virtual_disk_id;

    s_plugin_process := dbplugin_api.connect_to_plugin_server(PLUGIN_MODULE);                    -- Connect to the dbplugin_api.

    l_json_parameters.put('machineName', l_virtual_machine.machine_name);

    if l_virtual_machine.virtual_disk_id is not null then

      l_virtual_disk_filename := digital_bunker.generate_object_filename(p_object_id => l_virtual_machine.virtual_disk_id,
        p_gateway_name => s_plugin_process.get_string('pluginServer'), p_access_mode => dbobscura_api.READ_WRITE_ACCESS,
        p_linux_file_mode => 600, p_linux_subdir_mode => 705, p_disable_stream_write => 'Y',
        p_access_limit => dbobscura_api.unlimited_access_operations, p_valid_until => restapi.NO_EXPIRATION,
        p_file_user_group => 'root:root', p_subdir_user_group => 'root:root');

    end if;

    if l_virtual_machine.virtual_cdrom_id is not null then

      l_virtual_cdrom_filename := digital_bunker.generate_object_filename(p_object_id => l_virtual_machine.virtual_cdrom_id,
        p_access_limit => dbobscura_api.unlimited_access_operations,
        p_valid_until => restapi.NO_EXPIRATION, p_access_mode => dbobscura_api.READ_ONLY_ACCESS,
        p_linux_file_mode => 701, p_linux_subdir_mode => 705, p_file_user_group => 'qemu:qemu', p_subdir_user_group => 'root:root',
        p_gateway_name => s_plugin_process.get_string('pluginServer'));

    end if;

    l_json_parameters.put('vDiskFilename', l_virtual_disk_filename);
    if 'N' = l_object_created then

      l_json_parameters.put('vDiskSize', p_virtual_disk_size);
      l_json_parameters.put('sparseDiskAllocation', p_sparse_disk_allocation);

    end if;

    l_json_parameters.put('vCdromFilename', l_virtual_cdrom_filename);
    l_json_parameters.put('vCpus', l_virtual_machine.vcpu_count);
    l_json_parameters.put('vMemory', l_virtual_machine.virtual_memory);
    l_json_parameters.put('osVariant', l_virtual_machine.os_variant);
    l_json_parameters.put('networkSource', l_virtual_machine.network_source);
    l_json_parameters.put('networkDevice', l_virtual_machine.network_device);
    l_json_parameters.put('bootDevice', p_boot_device);

    l_json_response := dbplugin_api.call_plugin(s_plugin_process, 'startVirtualMachine', l_json_parameters);

    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);                 -- Disconnect from the plugin.

    if 'Y' = p_remove_cdrom_after_first_boot and
       'Y' = p_first_boot and l_virtual_machine.virtual_cdrom_id is not null then

      update  virtual_machines
         set  virtual_cdrom_id = null
       where  vm_id = p_vm_id;

    end if;

  end start_virtual_machine_action;

---
---
---

  function create_cloud_init_cdrom_image
  (
    p_user_id                         virtual_machines.user_id%type,
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
    l_json_parameters                 json_object_t := json_object_t;

  begin

    l_meta_data_id := digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => 'meta-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
        p_modification_date => null);

    l_user_data_id := digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => 'user-data.txt',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
        p_modification_date => null);

    if p_network_device_name is not null then

      l_net_data_id := digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => 'network-data.txt',
          p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
          p_modification_date => null);

    end if;

    l_cdrom_id := digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => p_machine_name||'.iso',
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
        p_modification_date => null);

    commit;

    l_content := 'instance-id: '||p_machine_name||chr(10)||
                 'local-hostname: '||p_local_hostname;

    l_clob := digital_bunker.manage_clob_locator(p_object_id => l_meta_data_id, p_for_update => restapi.OPTION_ENABLED);
    digital_bunker.set_lob_value(l_meta_data_id, restapi.CLOB_OBJECT_TYPE, null, l_content);
    l_clob := digital_bunker.manage_clob_locator(p_object_id => l_meta_data_id, p_release_lob_locator => restapi.OPTION_ENABLED,
      p_for_update => restapi.OPTION_ENABLED);

    l_content := '#cloud-config'||chr(10)||
      'user: '||p_user||chr(10)||
      'ssh_pwauth: True'||chr(10)||
      'ssh_authorized_keys: '||chr(10);

    for x in 0 .. p_authorized_ssh_keys.get_size - 1 loop

      l_content := l_content||'  - '||p_authorized_ssh_keys.get_string(x)||chr(10);

    end loop;

    l_clob := digital_bunker.manage_clob_locator(p_object_id => l_user_data_id, p_for_update => restapi.OPTION_ENABLED);
    digital_bunker.set_lob_value(l_user_data_id, restapi.CLOB_OBJECT_TYPE, null, l_content);
    l_clob := digital_bunker.manage_clob_locator(p_object_id => l_user_data_id, p_release_lob_locator => restapi.OPTION_ENABLED,
      p_for_update => restapi.OPTION_ENABLED);

    if p_network_device_name is not null then

      l_content := 'version: 1'||chr(10)||
        'config:'||chr(10)||
        '  - type: physical'||chr(10)||
        '    name: '||p_network_device_name||chr(10)||
        '    subnets:'||chr(10)||
        '      - type: static'||chr(10)||
        '        control: auto'||chr(10)||
        '        address: '||p_ip4_address||chr(10)||
        '        gateway: '||p_ip4_gateway||chr(10)||
        '        netmask: '||p_ip4_netmask||chr(10)||
        '        dns_nameservers:'||chr(10);


      for x in 0 .. p_dns_nameservers.get_size - 1 loop

        l_content := l_content||'          - '||p_dns_nameservers.get_string(x)||chr(10);

      end loop;

      l_content := l_content||'        dns_search:'||chr(10);
      for x in 0 .. p_dns_search.get_size - 1 loop

        l_content := l_content||'          - '||p_dns_search.get_string(x)||chr(10);

      end loop;

      l_clob := digital_bunker.manage_clob_locator(p_object_id => l_net_data_id, p_for_update => restapi.OPTION_ENABLED);
      digital_bunker.set_lob_value(l_net_data_id, restapi.CLOB_OBJECT_TYPE, null, l_content);
      l_clob := digital_bunker.manage_clob_locator(p_object_id => l_net_data_id, p_release_lob_locator => restapi.OPTION_ENABLED,
        p_for_update => restapi.OPTION_ENABLED);

    end if;

    s_plugin_process := dbplugin_api.connect_to_plugin_server(PLUGIN_MODULE);                    -- Connect to the dbplugin_api.


    l_meta_data_filename := digital_bunker.generate_object_filename(p_object_id => l_meta_data_id,
        p_gateway_name => s_plugin_process.get_string('pluginServer'), p_access_mode => dbobscura_api.READ_ONLY_ACCESS);
    l_user_data_filename := digital_bunker.generate_object_filename(p_object_id => l_user_data_id,
        p_gateway_name => s_plugin_process.get_string('pluginServer'), p_access_mode => dbobscura_api.READ_ONLY_ACCESS);

    if p_network_device_name is not null then

      l_net_data_filename := digital_bunker.generate_object_filename(p_object_id => l_net_data_id,
          p_gateway_name => s_plugin_process.get_string('pluginServer'), p_access_mode => dbobscura_api.READ_ONLY_ACCESS);

    end if;

    l_cdrom_filename := digital_bunker.generate_object_filename(p_object_id => l_cdrom_id,
        p_gateway_name => s_plugin_process.get_string('pluginServer'), p_access_mode => dbobscura_api.WRITE_ACCESS);

    commit;

    l_json_parameters.put('metaDataFilename', l_meta_data_filename);
    l_json_parameters.put('userDataFilename', l_user_data_filename);
    if p_network_device_name is not null then

      l_json_parameters.put('netDataFilename', l_net_data_filename);

    end if;

    l_json_parameters.put('vCdromFilename', l_cdrom_filename);

    l_json_response := dbplugin_api.call_plugin(s_plugin_process, 'createCloudInitCdrom', l_json_parameters);

    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);                 -- Disconnect from the plugin.

    return l_cdrom_id;

  end create_cloud_init_cdrom_image;

  function create_cloud_init_cdrom_image
  (
    p_user_id                         virtual_machines.user_id%type,
    p_machine_name                    virtual_machines.machine_name%type,
    p_meta_data_file                  vault_objects.object_id%type,
    p_user_data_file                  vault_objects.object_id%type,
    p_network_config_file             vault_objects.object_id%type
  )
  return vault_objects.object_id%type

  is

    l_meta_data_filename              varchar2(256);
    l_user_data_filename              varchar2(256);
    l_net_data_filename               varchar2(256);
    l_cdrom_filename                  varchar2(256);

    l_clob                            clob;

    l_json_response                   json_object_t;
    l_json_parameters                 json_object_t := json_object_t;

  begin

    null;

  end create_cloud_init_cdrom_image;

  function create_virtual_disk
  (
    p_user_id                         virtual_machines.user_id%type,
    p_disk_image_name                 object_versions.source_path%type,
    p_seed_image_id                   vault_objects.object_id%type
  )
  return vault_objects.object_id%type

  is

    l_dest_object_id                  vault_objects.object_id%type;

    l_source_data_type                object_types.data_type%type;

    l_source_clob                     clob;
    l_source_blob                     blob;

    l_dest_clob                       clob;
    l_dest_blob                       blob;

  begin

    select  data_type
      into  l_source_data_type
      from  object_types t, file_extensions e, vault_objects o
     where  o.object_id = p_seed_image_id
       and  o.extension_id = e.extension_id
       and  e.object_type_id = t.object_type_id;

    l_dest_object_id := digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => p_disk_image_name,
        p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
        p_modification_date => null);

    commit;

    if 'CLOB' = l_source_data_type then

      l_source_clob := digital_bunker.manage_clob_locator(p_object_id => p_seed_image_id);

      l_dest_clob := digital_bunker.manage_clob_locator(p_object_id => l_dest_object_id, p_for_update => restapi.OPTION_ENABLED);
      digital_bunker.set_lob_value(l_dest_object_id, restapi.CLOB_OBJECT_TYPE, null, l_source_clob);
      l_dest_clob := digital_bunker.manage_clob_locator(p_object_id => l_dest_object_id, p_release_lob_locator => restapi.OPTION_ENABLED,
        p_for_update => restapi.OPTION_ENABLED);

    end if;

    if 'BLOB' = l_source_data_type then

      l_source_blob := digital_bunker.manage_blob_locator(p_object_id => p_seed_image_id);

      l_dest_blob := digital_bunker.manage_blob_locator(p_object_id => l_dest_object_id, p_for_update => restapi.OPTION_ENABLED);
      digital_bunker.set_lob_value(l_dest_object_id, restapi.BLOB_OBJECT_TYPE, l_source_blob, null);
      l_dest_blob := digital_bunker.manage_blob_locator(p_object_id => l_dest_object_id, p_release_lob_locator => restapi.OPTION_ENABLED,
        p_for_update => restapi.OPTION_ENABLED);

    end if;

    return l_dest_object_id;

  end create_virtual_disk;

  function create_virtual_disk
  (
    p_user_id                         virtual_machines.user_id%type,
    p_disk_image_name                 object_versions.source_path%type
  )
  return vault_objects.object_id%type

  is

  begin

    return digital_bunker.create_an_object(p_user_id => p_user_id, p_source_path => p_disk_image_name,
      p_client_address => sys_context('userenv', 'ip_address'), p_program_name => 'vm_manager',
      p_modification_date => null);

  end create_virtual_disk;

  function create_virtual_machine
  (
    p_user_id                         virtual_machines.user_id%type,
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
  return virtual_machines.vm_id%type

  is

    l_vm_id                           virtual_machines.vm_id%type;
    l_object_created                  vault_objects.object_created%type;

  begin

    if p_virtual_disk_id is null and p_virtual_cdrom_id is null then

      error_logging.raise_api_error(error_logging.GENERIC_EXTENSION_ERROR, 'A virtual disk or cdrom must be specified.');

    end if;

    if p_boot_device not in ('hd', 'cdrom') then

      error_logging.raise_api_error(error_logging.GENERIC_EXTENSION_ERROR, 'Invalid boot device specified.');

    end if;

    if p_virtual_disk_id is not null then

      select  object_created
        into  l_object_created
        from  vault_objects
       where  object_id = p_virtual_disk_id;

      if 'N' = l_object_created and nvl(p_virtual_disk_size, 0) = 0 then

        error_logging.raise_api_error(error_logging.GENERIC_EXTENSION_ERROR, 'A file size, in MB, must be provided for the new virtual disk image.');

      end if;

    end if;

    insert into virtual_machines
      (vm_id, user_id, machine_name, virtual_disk_id, virtual_cdrom_id, vcpu_count, virtual_memory, os_variant,
       network_source, network_device)
    values
      (id_seq.nextval, p_user_id, p_machine_name, p_virtual_disk_id, p_virtual_cdrom_id, p_vcpu_count, p_virtual_memory,
       p_os_variant, p_network_source, p_network_device)
    returning vm_id into l_vm_id;

    start_virtual_machine_action(p_vm_id => l_vm_id, p_virtual_disk_size => p_virtual_disk_size, p_sparse_disk_allocation => p_sparse_disk_allocation,
      p_boot_device => p_boot_device, p_remove_cdrom_after_first_boot => p_remove_cdrom_after_first_boot, p_first_boot => 'Y');

    return l_vm_id;

  end create_virtual_machine;

  procedure delete_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  )

  is

  begin

    delete
      from  virtual_machines
     where  vm_id = p_vm_id;

  end delete_virtual_machine;

  procedure start_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type,
    p_boot_device                     varchar2 default 'hd'
  )

  is

  begin

    start_virtual_machine_action(p_vm_id => p_vm_id, p_boot_device => p_boot_device);

  end start_virtual_machine;

  procedure undefine_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  )

  is

    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_json_response                   json_object_t;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  vm_id = p_vm_id;

    s_plugin_process := dbplugin_api.connect_to_plugin_server(PLUGIN_MODULE);                    -- Connect to the dbplugin_api.
    l_json_parameters.put('machineName', l_virtual_machine.machine_name);
    l_json_response := dbplugin_api.call_plugin(s_plugin_process, 'undefineVirtualMachine', l_json_parameters);
    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);                 -- Disconnect from the plugin.

  end undefine_virtual_machine;

  procedure stop_virtual_machine
  (
    p_vm_id                           virtual_machines.vm_id%type
  )

  is

    l_virtual_machine                 virtual_machines%rowtype;
    l_json_parameters                 json_object_t := json_object_t;
    l_json_response                   json_object_t;

  begin

    select  *
      into  l_virtual_machine
      from  virtual_machines
     where  vm_id = p_vm_id;

    s_plugin_process := dbplugin_api.connect_to_plugin_server(PLUGIN_MODULE);                    -- Connect to the dbplugin_api.
    l_json_parameters.put('machineName', l_virtual_machine.machine_name);
    l_json_response := dbplugin_api.call_plugin(s_plugin_process, 'stopVirtualMachine', l_json_parameters);
    dbplugin_api.disconnect_from_plugin_server(s_plugin_process);                 -- Disconnect from the plugin.

  end stop_virtual_machine;

end vm_manager;
/
show errors package body oci_interface
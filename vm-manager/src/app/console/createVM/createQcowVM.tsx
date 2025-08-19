'use client'

import { createQcowVmFromTemplate, createQcowVmUsingConfigFiles } from "@/utils/serverFunctions";
import { Card, CardBody, Tabs, Tab, Checkbox, Textarea, Input, Button, Divider, Autocomplete, AutocompleteItem } from "@heroui/react";
import { useRouter } from "next/navigation";
import React, { useState, useContext, useCallback, FocusEvent, ChangeEvent } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { Select, SelectItem } from "@heroui/select";
import { OsVariantsT, SeedImagesT, NameserverT, SshKeyT, SetIpCallbackT, RefreshVirtualMachineListT, VmHostsT, AttachedStorageT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import { VmManagerContext } from "@/utils/vmManagerContext";

interface CreateQcowVMPropsI 
{
  osVariants: OsVariantsT;
  qcow2Images: SeedImagesT;
  refreshVirtualMachineList: RefreshVirtualMachineListT;
  vmHosts?: VmHostsT
};

export default function CreateQcowVM({ osVariants, qcow2Images, refreshVirtualMachineList, vmHosts }: CreateQcowVMPropsI) 
{
  const [ diskSize, setDiskSize ] = useState('0');
  const [ diskLabel, setDiskLabel ] = useState('');

  const [ qcowImage, setQcowImage ] = useState('');
  const [ qcowVmImageName, setQcowVmImageName ] = useState('');
  const [ qcowOsVariantId, setQcowOsVariantId ] = useState<React.Key | null>('');
  const [ qcowVCpus, setQcowVCpus ] = useState('2');
  const [ qcowVMemory, setQcowVMemory ] = useState('2');
  const [ qcowBridged, setQcowBridged ] = useState(false);
  const [ qcowNetworkDevice, setQcowNetworkDevice ] = useState('default');

  const [ metaData, setMetaData ] = useState('');
  const [ userData, setUserData ] = useState('');
  const [ networkConfig, setNetworkConfig ] = useState('');

  const [ localhost, setLocalhost ] = useState('');
  const [ adminUser, setAdminUser ] = useState('');
  const [ adminPassword, setAdminPassword ] = useState('');

  const [ ip4Address, setIp4Address ] = useState('');
  const [ ip4AddressIsInvalid, setIp4AddressIsInvalid ] = useState<boolean>(false);
  const [ ip4Netmask, setIp4Netmask ] = useState('');
  const [ ip4NetmaskIsInvalid, setIp4NetmaskIsInvalid ] = useState<boolean>(false);
  const [ ip4Gateway, setIp4Gateway ] = useState('');
  const [ ip4GatewayIsInvalid, setIp4GatewayIsInvalid ] = useState<boolean>(false);

  const ipAddressRegex = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;

  const [ nameserver, setNameserver ] = useState('');
  const [ nameserverIsInvalid, setNameserverIsInvalid ] = useState(false);
  const [ nameservers, setNameservers] = useState<NameserverT []>([]);
  const [ nameserverKey, setNameserverKey ] = useState(0);
  const [ dnsSearch, setDnsSearch ] = useState('');

  const [ sshKey, setSshKey ] = useState('');
  const [ sshKeys, setSshKeys ] = useState<SshKeyT []>([]);
  const [ sshTableKey, setSshTableKey ] = useState(0);

  const [ vmHostId, setVmHostId ] = useState('');

  const sshColumns =
  [
    { key: 'pubKey', label: 'Public Key'},
    { key: 'action', label: 'Action'}
  ];

  const nameserverColumns = 
  [
    { key: 'nameserver', label: 'Nameserver'},
    { key: 'action', label: 'Action'}
  ];

  const router = useRouter();

  const vmManagerContext = useContext(VmManagerContext);

  function addSshKey()
  {
    const newKey: SshKeyT = { id: getRandomInt(1, 1000), sshKey};
    setSshKeys([ ...sshKeys, newKey ]);
    setSshTableKey(key => key + 1);
    setSshKey('');
  }

  function addNameserver()
  {
    if (nameserverIsInvalid) return;
    const newNameserver: NameserverT = { id: getRandomInt(1, 1000), nameserver };
    setNameservers([ ...nameservers, newNameserver ]);
    setNameserverKey( key => key + 1);
    setNameserver('');
  }

  function callCreateQcowVmUsingConfigFiles()
  {
    let attachedStorage: []|[AttachedStorageT] = [];

    if (parseInt(diskSize))
    {
      attachedStorage = [{ diskLabel, diskSize: parseInt(diskSize) }];
    }

    vmManagerContext?.setSpinnerState(true, 'Creating VM....');
    createQcowVmUsingConfigFiles(qcowVmImageName, qcowImage, parseInt(qcowOsVariantId as string), vmHostId, parseInt(qcowVCpus), parseInt(qcowVMemory), 
      qcowBridged ? 'Y' : 'N', qcowNetworkDevice, metaData, userData, networkConfig, attachedStorage).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: "primary", title: "VM Created"});
      refreshVirtualMachineList();
    });
  }

  function callCreateQcowVmFromTemplate()
  {
    let attachedStorage: []|[AttachedStorageT] = [];

    if (parseInt(diskSize))
    {
      attachedStorage = [{ diskLabel, diskSize: parseInt(diskSize) }];
    }

    vmManagerContext?.setSpinnerState(true, 'Creating VM....');
    createQcowVmFromTemplate(qcowVmImageName, qcowImage, parseInt(qcowOsVariantId as string), vmHostId, parseInt(qcowVCpus), parseInt(qcowVMemory), 
      qcowBridged ? 'Y' : 'N', qcowNetworkDevice, localhost, ip4Address, ip4Gateway, ip4Netmask, nameservers as NameserverT[], dnsSearch, sshKeys, 
      attachedStorage, adminUser, adminPassword).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: "primary", title: "VM Created"});
      refreshVirtualMachineList();
    });
  }

  function getRandomInt(min: number, max: number) 
  {
    const minCeiled = Math.ceil(min);
    const maxFloored = Math.floor(max);
    return Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled); // The maximum is exclusive and the minimum is inclusive
  }
  
  function onChangeHandler(setFunction: React.Dispatch<React.SetStateAction<string>>, event: ChangeEvent<HTMLSelectElement>)
  {
    setFunction(event.target.value);
  }

  const renderSshCell = useCallback((sshKeys: SshKeyT [], sshKey: SshKeyT, columnKey: React.Key) =>
  {
    function removeSshKey(id: number)
    {
      setSshTableKey(key => key+1)      
      setSshKeys(sshKeys.filter(x => x.id !== id));
    }
  
    switch (columnKey)
    {
      case 'action':
        return(<div><Button onPress={removeSshKey.bind(removeSshKey, sshKey.id)} >Delete</Button></div>);

      default:
        return(<div className="max-w-64 overflow-hidden">{sshKey.sshKey.substring(0, 20) + '...' + sshKey.sshKey.substring(sshKey.sshKey.length - 20)}</div>);
    }
  }, []);

  const removeNameserver = useCallback((id: number) =>
  {
    setNameserverKey(key => key +1);
    setNameservers(nameservers.filter(x => x.id !== id));
  }, [ nameservers ]);

  function renderNameserverCell(nameserver: NameserverT, columnKey: React.Key)
  {
    switch (columnKey)
    {
      case 'action': 
        return(<div><Button onPress={removeNameserver.bind(removeNameserver, nameserver.id)}>Delete</Button></div>);

      default:
        return(<div className="max-w-64">{nameserver.nameserver}</div>);
    }
  }

  function validateIpAddress(setIsInvalid: SetIpCallbackT, event: FocusEvent<HTMLInputElement>)
  {
    if ('' === event.target.value) 
    {
      setIsInvalid(false);
      return;
    }
    setIsInvalid(!ipAddressRegex.test(event.target.value));
  }

  return (
    <>
      <div className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pt-6 pb-6">
        <Select className="w-80" label="Select a QCOW2 image" onChange={onChangeHandler.bind(onChangeHandler, setQcowImage)} selectedKeys={[qcowImage]}>
        {qcow2Images.map((qcow2Image) => 
        (
          <SelectItem className={"w-lg"} key={qcow2Image.objectId}>{qcow2Image.objectName + ' - ' + qcow2Image.fileExtension}</SelectItem>
        ))}
        </Select>
        <div>
          <Autocomplete className="max-w-xs" label="Select an os-variant" defaultItems={osVariants} onSelectionChange={setQcowOsVariantId} selectedKey={String(qcowOsVariantId)} isVirtualized={true} >
            { (item) => <AutocompleteItem className={"w-lg"} key={item.variantId}>{item.longName}</AutocompleteItem> }
          </Autocomplete>
        </div>
      </div>
      <div  className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pb-6">
        <Input value={qcowVmImageName} onValueChange={setQcowVmImageName} label="VM Image Name"/>
        <Select className="w-80" label="Select a VM Host Server" onChange={onChangeHandler.bind(onChangeHandler, setVmHostId)} selectedKeys={[vmHostId]}>
          {/* @ts-ignore */}
          {vmHosts.map((vmHost) =>
          (
            <SelectItem className={"w-lg"} key={vmHost.hostId}>{vmHost.hostName}</SelectItem>
          ))}
        </Select>
      </div>
      <Divider />
      <div className="pt-6 pb-6 columns-1">Additional Storage</div>
      <div className="columns-2 flex gap-4 pb-6">
        <Input className="w-32" label="Disk Size" labelPlacement="outside" value={diskSize} onValueChange={setDiskSize} type="number" min={0}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
        <Input value={diskLabel} onValueChange={setDiskLabel} label="Volume Name" labelPlacement="outside" type="text"></Input>
      </div>
      <Divider />
      <div className="columns-4 flex gap-4 pt-6 pb-6">
        <Input className="w-24" label="VCPU's" labelPlacement="outside" value={qcowVCpus} onValueChange={setQcowVCpus} type="number"  min={1}></Input>
        <Input className="w-24" label="VMemory" labelPlacement="outside" value={qcowVMemory} onValueChange={setQcowVMemory} type="number" min={1}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
        <Checkbox className="pt-8" isSelected={qcowBridged} onValueChange={setQcowBridged} >Bridged Connection</Checkbox>
        <Input className="w-32" label="Device Name" value={qcowNetworkDevice} onValueChange={setQcowNetworkDevice} type="text" labelPlacement="outside"></Input>
      </div>
      <Tabs aria-label="Options">
        <Tab key="cloudInitFiles" title="Cloud-Init Files">
          <Card>
            <CardBody>
              <div className="columns-3 flex gap-4 pt-6 pb-6">
                <Textarea className="max-w-xs" label="Meta Data" value={metaData} onValueChange={setMetaData} />
                <Textarea className="max-w-xs" label="User Data"  value={userData} onValueChange={setUserData} />
                <Textarea className="max-w-xs" label="Network Config" value={networkConfig} onValueChange={setNetworkConfig} />
              </div>
              <div className="columns-1">
                <Button color="primary" type="button" onPress={callCreateQcowVmUsingConfigFiles}>Create VM</Button>
              </div>
            </CardBody>
          </Card>
        </Tab>
        <Tab key="cloudInitTemplate" title="Cloud-Init Template">
          <Card>
            <CardBody>
              <div className="columns-3 flex flex-row gap-4 pt-6 pb-6">
                <Input className="w-64" label="localhost-name" value={localhost} onValueChange={setLocalhost} type="text" labelPlacement="outside"></Input>
                <Input className="w-32" label="Admin Username" value={adminUser} onValueChange={setAdminUser} type="text" labelPlacement="outside"></Input>
                <Input className="w-32" label="Admin Password (optional)" value={adminPassword} onValueChange={setAdminPassword} type="password" labelPlacement="outside"></Input>
              </div>  
              <div className="columns-4 flex flex-row gap-4 pt-6 pb-6">
                <Input className="w-32" value={ip4Address} label="ip4Address" isInvalid={ip4AddressIsInvalid} onValueChange={setIp4Address} errorMessage="Enter a valid IP Address"
                  onBlur={validateIpAddress.bind(validateIpAddress, setIp4AddressIsInvalid)} type="text" labelPlacement="outside"/>
                <Input className="w-32" value={ip4Netmask} label="ip4Netmask" isInvalid={ip4NetmaskIsInvalid} onValueChange={setIp4Netmask} errorMessage="Enter a valid IP Netmask"
                  onBlur={validateIpAddress.bind(validateIpAddress, setIp4NetmaskIsInvalid)} type="text" labelPlacement="outside"/>
                <Input className="w-32" value={ip4Gateway} label="ip4Gateway" isInvalid={ip4GatewayIsInvalid} onValueChange={setIp4Gateway} errorMessage="Enter a valid IP Gateway"
                  onBlur={validateIpAddress.bind(validateIpAddress, setIp4GatewayIsInvalid)} type="text" labelPlacement="outside"/>
                <Input className="w-64" label="Additional DNS Search Domains (separated by a space)" value={dnsSearch} onValueChange={setDnsSearch} type="text" labelPlacement="outside"></Input>
              </div>
              <div className="flex columns-2 gap-4 pt-6 pb-6">
                <div >
                  <Input className="w-32" value={nameserver} isInvalid={nameserverIsInvalid} label="nameserver" onValueChange={setNameserver} errorMessage="Enter a valid IP Address"
                    onBlur={validateIpAddress.bind(validateIpAddress, setNameserverIsInvalid)} type="text" labelPlacement="outside"/>
                  <Button color="primary" type="button" onPress={addNameserver}>Add</Button>
                </div>
                <div >
                <Table key={nameserverKey} aria-label="table-of-nameservers">
                    <TableHeader columns={nameserverColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
                    <TableBody items={nameservers} >
                    {(item) => 
                    (
                      <TableRow key={item.id} >
                        {(columnKey) => <TableCell>{renderNameserverCell(item, columnKey)}</TableCell>}
                      </TableRow>
                    )}
                    </TableBody>
                  </Table>
                </div>
              </div>
              <div className="flex gap-4 pt-6 pb-6">
                <div >
                  <Input className="flex-none w-64 pb-6" label="Public SSH Key" value={sshKey} onValueChange={setSshKey} type="text" labelPlacement="outside"></Input>
                  <Button color="primary" type="button" onPress={addSshKey}>Add</Button>
                </div>
                <div >
                  <Table aria-label="table-of-ssh-keys" key={sshTableKey}>
                    <TableHeader columns={sshColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
                    <TableBody items={sshKeys} >
                    {(item) => 
                    (
                      <TableRow key={item.id} >
                        {(columnKey) => <TableCell>{renderSshCell(sshKeys, item, columnKey)}</TableCell>}
                      </TableRow>
                    )}
                    </TableBody>
                  </Table>
                </div>
              </div>
              <div className="columns-1">
                <Button color="primary" type="button" onPress={callCreateQcowVmFromTemplate}>Create VM</Button>
              </div>
            </CardBody>
          </Card>
        </Tab>
      </Tabs>
    </>
  );
}
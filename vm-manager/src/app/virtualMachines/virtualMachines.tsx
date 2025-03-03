'use client'

import { getVirtualMachines, createVmFromIsoImage, createQcowVmFromTemplate, createQcowVmUsingConfigFiles, startVirtualMachine, stopVirtualMachine, terminateUserSession, 
  undefineVirtualMachine } from "@/utls/serverFunctions";
import { Card, CardBody, Tabs, Tab, Checkbox, Textarea, Input, Button, Divider, Autocomplete, AutocompleteItem } from "@heroui/react";
import { useRouter } from "next/navigation";
import React, { useState, useCallback, FocusEvent, ChangeEvent } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { Select, SelectItem } from "@heroui/select";
import { OsVariantsT, SeedImagesT, VirtualMachinesT, NameserverT, SshKeyT } from "@/utls/dataTypes";

interface VirtualMachinePropsI 
{
  osVariants: OsVariantsT;
  isoImages: SeedImagesT;
  qcow2Images: SeedImagesT;
  vmImages: VirtualMachinesT;
};

type setIpCallbackT = (state: boolean) => void;

export default function VirtualMachines({ osVariants, isoImages, qcow2Images, vmImages}: VirtualMachinePropsI) 
{
  const [ virtualMachines, setVirtualMachines ] = useState(vmImages);

  const [ isoImage, setIsoImage ] = useState('');
  const [ isoVmImageName, setIsoVmImageName ] = useState('');
  const [ isoOsVariantId, setIsoOsVariantId ] = useState<React.Key | null>('');
  const [ isoVDiskSize, setIsoVDiskSize ] = useState('5');
  const [ isoVCpus, setIsoVCpus ] = useState('2');
  const [ isoVMemory, setIsoVMemory ] = useState('2');
  const [ isoBridged, setIsoBridged ] = useState(false);
  const [ isoNetworkDevice, setIsoNetworkDevice ] = useState('default');

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

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'action', label: 'Action' }
  ];

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

  type VirtualMachineT = (typeof virtualMachines)[0];

  function getRandomInt(min: number, max: number) 
  {
    const minCeiled = Math.ceil(min);
    const maxFloored = Math.floor(max);
    return Math.floor(Math.random() * (maxFloored - minCeiled) + minCeiled); // The maximum is exclusive and the minimum is inclusive
  }
  
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

  function callCreateVmFromIsoImage()
  {
    createVmFromIsoImage(isoVmImageName, isoImage, parseInt(isoOsVariantId as string), parseInt(isoVDiskSize), 'Y', 
      parseInt(isoVCpus), parseInt(isoVMemory), isoBridged ? 'Y' : 'N', isoNetworkDevice).then((response) =>
    {
      console.log(response);
      getVirtualMachines().then((response) =>
      {
        if (!response.ok)
        {
          console.log(response);
        }
        setVirtualMachines(response.jsonData.virtualMachines);
      }); 
    });
  }

  function callCreateQcowVmUsingConfigFiles()
  {
    createQcowVmUsingConfigFiles(qcowVmImageName, qcowImage, parseInt(qcowOsVariantId as string), parseInt(qcowVCpus), parseInt(qcowVMemory), 
      qcowBridged ? 'Y' : 'N', qcowNetworkDevice, metaData, userData, networkConfig).then((response) =>
    {
      console.log(response);
      if (response.ok)
      {
        getVirtualMachines().then((response) =>
        {
          if (!response.ok)
          {
            console.log(response);
          }
          setVirtualMachines(response.jsonData.virtualMachines);
        }); 
      }
    });
  }

  function callCreateQcowVmFromTemplate()
  {
//    const x = nameservers as NameserverT[];

    createQcowVmFromTemplate(qcowVmImageName, qcowImage, parseInt(qcowOsVariantId as string), parseInt(qcowVCpus), parseInt(qcowVMemory), 
      qcowBridged ? 'Y' : 'N', qcowNetworkDevice, localhost, ip4Address, ip4Gateway, ip4Netmask, nameservers as NameserverT[], dnsSearch, sshKeys, 
      adminUser, adminPassword).then((response) =>
    {
      console.log(response);
      if (response.ok)
      {
        getVirtualMachines().then((response) =>
        {
          if (!response.ok)
          {
            console.log(response);
          }
          setVirtualMachines(response.jsonData.virtualMachines);
        }); 
      }
    });
  }

  function logout()
  {
    terminateUserSession().then((response) =>
    {
      console.log(response);
      if (response.ok) router.push('/login');
    });
  }

  function startVirtualMachineHandler(virtualMachineId: number)
  {
    startVirtualMachine(virtualMachineId).then((response) =>
    {
      console.log(response);
    })
  }

  function stopVirtualMachineHandler(virtualMachineId: number)
  {
    stopVirtualMachine(virtualMachineId).then((response) =>
    {
      console.log(response);
    })
  }

  function undefineVirtualMachineHandler(virtualMachineId: number)
  {
    undefineVirtualMachine(virtualMachineId).then((response) =>
    {
      console.log(response);
    })
  }

  const renderVmCell = useCallback((virtualMachine: VirtualMachineT, columnKey: React.Key, virtualMachineId: number) => 
  {
    const cellValue = virtualMachine[columnKey as keyof VirtualMachineT];
    switch (columnKey) 
    {
      case 'action':
        return(
          <div>
            <Button onPress={startVirtualMachineHandler.bind(startVirtualMachineHandler, virtualMachineId)} >Start VM</Button>
            <Button onPress={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, virtualMachineId)} >Stop VM</Button>
            <Button onPress={undefineVirtualMachineHandler.bind(undefineVirtualMachineHandler, virtualMachineId)} >Undefine VM</Button>
          </div>);

      default:
        return cellValue;
    }
  }, []);

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

  function onChangeHandler(setFunction: React.Dispatch<React.SetStateAction<string>>, event: ChangeEvent<HTMLSelectElement>)
  {
    setFunction(event.target.value);
  }

  return (
    <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
      <p className="pb-6" ><b>Virtual Machines...</b></p>
      <div>
        <Table aria-label="List of Virtual Machines">
          <TableHeader columns={vmColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
          <TableBody items={virtualMachines}>        
          {(item) => 
          (
            <TableRow key={item.virtualMachineId}>
              {(columnKey) => <TableCell>{renderVmCell(item, columnKey, item.virtualMachineId)}</TableCell>}
            </TableRow>
          )}
          </TableBody>
        </Table>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div>
        <div><p><b>Create a Virtual Machine from an ISO image</b></p></div>
        <div className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pt-6 pb-6">
          <Select className="w-80" label="Select an ISO image" onChange={onChangeHandler.bind(onChangeHandler, setIsoImage)} selectedKeys={[isoImage]}>
            {isoImages.map((isoImage) => 
            (
              <SelectItem className={"w-lg"} key={isoImage.objectId}>{isoImage.objectName + ' - ' + isoImage.fileExtension}</SelectItem>
            ))}
          </Select>
          <div>
            <Autocomplete className="max-w-xs" label="Select an os-variant" defaultItems={osVariants} onSelectionChange={setIsoOsVariantId} selectedKey={String(isoOsVariantId)} isVirtualized={true} >
              { (item) => <AutocompleteItem className={"w-lg"} key={item.variantId}>{item.longName}</AutocompleteItem> }
            </Autocomplete>
          </div>
        </div>
        <div  className="columns-1 flex w-full flex-wrap md:flex-nowrap gap-4">
          <Input value={isoVmImageName} onValueChange={setIsoVmImageName} label="VM Image Name"/>
        </div>
        <div className="columns-5 flex gap-4 pt-6 pb-6">
          <Input className="w-24" label="VDisk Size" labelPlacement="outside" value={isoVDiskSize} onValueChange={setIsoVDiskSize} type="number" 
            endContent=
            {
              <div className="pointer-events-none flex items-center">
                <span className="text-default-400 text-small">GB</span>
              </div>
            }
          ></Input>
          <Input className="w-24" label="VCPU's" labelPlacement="outside" value={isoVCpus} onValueChange={setIsoVCpus} type="number" ></Input>
          <Input className="w-24" label="VMemory" labelPlacement="outside" value={isoVMemory} onValueChange={setIsoVMemory} type="number" 
            endContent=
            {
              <div className="pointer-events-none flex items-center">
                <span className="text-default-400 text-small">GB</span>
              </div>
            }
          ></Input>
          <Checkbox className="pt-8" isSelected={isoBridged} onValueChange={setIsoBridged} >Bridged Connection</Checkbox>
          <Input className="w-32" label="Device Name" value={isoNetworkDevice} onValueChange={setIsoNetworkDevice} type="text" labelPlacement="outside"></Input>
        </div>
        <Button color="primary" type="button" onPress={callCreateVmFromIsoImage}>Create VM</Button>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div>
        <div><p><b>Create a Virtual Machine from a QCOW2 seed</b></p></div>
          <div className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pt-6 pb-6">
            <Select className="w-80" label="Select a QCOW2 image" onChange={onChangeHandler.bind(onChangeHandler, setQcowImage)} selectedKeys={qcowImage}>
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
        <div  className="columns-1 flex w-full flex-wrap md:flex-nowrap gap-4">
          <Input value={qcowVmImageName} onValueChange={setQcowVmImageName} label="VM Image Name"/>
        </div>
        <div className="columns-5 flex gap-4 pt-6 pb-6">
          <Input className="w-24" label="VCPU's" labelPlacement="outside" value={qcowVCpus} onValueChange={setQcowVCpus} type="number" ></Input>
          <Input className="w-24" label="VMemory" labelPlacement="outside" value={qcowVMemory} onValueChange={setQcowVMemory} type="number" 
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
                  <Input className="w-64" label="DNS Search Domains" value={dnsSearch} onValueChange={setDnsSearch} type="text" labelPlacement="outside"></Input>
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
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div>
        <Button color="primary" type="button" onPress={logout}>Log Out...</Button>
      </div>
    </div>
  );

  function validateIpAddress(setIsInvalid: setIpCallbackT, event: FocusEvent<HTMLInputElement>)
  {
    if ('' === event.target.value) 
    {
      setIsInvalid(false);
      return;
    }
    setIsInvalid(!ipAddressRegex.test(event.target.value));
  }
}
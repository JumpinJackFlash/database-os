'use client'

import { createVmFromIsoImage, startVirtualMachine, stopVirtualMachine, terminateUserSession, undefineVirtualMachine } from "@/utls/serverActions";
import { Checkbox, Input, Button, Divider, Autocomplete, AutocompleteItem } from "@heroui/react";
import { useRouter } from "next/navigation";
import { useState, useEffect, useCallback } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell, getKeyValue } from "@heroui/table";
import {Select, SelectItem } from "@heroui/select";

export default function VirtualMachines(props: any) 
{
  const { osVariants, isoImages, virtualMachines } = props;

  const [ isoImage, setIsoImage ] = useState(new Set([]));
  const [ vmImageName, setVmImageName ] = useState('');
  const [ osVariantId, setOsVariantId ] = useState(0);
  const [ vDiskSize, setVDiskSize ] = useState('5');
  const [ vCpus, setVCpus ] = useState('2');
  const [ vMemory, setVMemory ] = useState('2');
  const [ bridged, setBridged ] = useState(false);
  const [ networkDevice, setNetworkDevice ] = useState('default');

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'action', label: 'Action' }
  ];

  const router = useRouter();

  type VirtualMachineT = (typeof virtualMachines)[0];

  function callCreateVmFromIsoImage()
  {
    let isoImageIter = isoImage.values();

    let result = createVmFromIsoImage(vmImageName, isoImageIter.next().value, osVariantId, parseInt(vDiskSize), 'Y', 
      parseInt(vCpus), parseInt(vMemory), bridged ? 'Y' : 'N', networkDevice).then((response) =>
      {
        console.log(response);
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

  function startVirtualMachineHandler(vmId: number)
  {
    startVirtualMachine(vmId).then((response) =>
    {
      console.log(response);
    })
  }

  function stopVirtualMachineHandler(vmId: number)
  {
    stopVirtualMachine(vmId).then((response) =>
    {
      console.log(response);
    })
  }

  function undefineVirtualMachineHandler(vmId: number)
  {
    undefineVirtualMachine(vmId).then((response) =>
    {
      console.log(response);
    })
  }

  const renderCell = useCallback((virtualMachine: VirtualMachineT, columnKey: React.Key, vmId: number) => 
  {
    const cellValue = virtualMachine[columnKey as keyof VirtualMachineT];
    switch (columnKey) 
    {
      case 'action':
        return(
          <div>
            <Button onPress={startVirtualMachineHandler.bind(startVirtualMachineHandler, vmId)} >Start VM</Button>
            <Button onPress={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, vmId)} >Stop VM</Button>
            <Button onPress={undefineVirtualMachineHandler.bind(undefineVirtualMachineHandler, vmId)} >Undefine VM</Button>
          </div>);

      default:
        return cellValue;
    }
  }, []);

  return (
    <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
      <p className="pb-6" >Virtual Machines...</p>
      <div>
        <Table aria-label="List of Virtual Machines">
          <TableHeader columns={vmColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
          <TableBody items={virtualMachines}>        
          {(item) => 
          (
            <TableRow key={item.vmId}>
              {(columnKey) => <TableCell>{renderCell(item, columnKey, item.vmId)}</TableCell>}
            </TableRow>
          )}
          </TableBody>
        </Table>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div>
        <div><p>Create a Virtual Machine from an ISO image</p></div>
        <div className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pt-6 pb-6">
          <Select className="w-80" label="Select an ISO image" onSelectionChange={setIsoImage} selectedKeys={isoImage}>
            {isoImages.map((isoImage) => 
            (
              <SelectItem className={"w-lg"} key={isoImage.objectId}>{isoImage.objectName + ' - ' + isoImage.fileExtension}</SelectItem>
            ))}
          </Select>
          <div>
            <Autocomplete className="max-w-xs" label="Select an os-variant" onSelectionChange={setOsVariantId} selectedKeys={osVariantId} isVirtualized={true} >
              {osVariants.map((osVariant) => 
              (
                <AutocompleteItem className={"w-lg"} key={osVariant.variantId}>{osVariant.longName}</AutocompleteItem>
              ))}
            </Autocomplete>
          </div>
        </div>
        <div  className="columns-1 flex w-full flex-wrap md:flex-nowrap gap-4">
          <Input value={vmImageName} onValueChange={setVmImageName} label="VM Image Name"/>
        </div>
        <div className="columns-5 flex gap-4 pt-6 pb-6">
          <Input className="w-24" label="VDisk Size" labelPlacement="outside" value={vDiskSize} onValueChange={setVDiskSize} type="number" 
            endContent=
            {
              <div className="pointer-events-none flex items-center">
                <span className="text-default-400 text-small">GB</span>
              </div>
            }
          ></Input>
          <Input className="w-24" label="VCPU's" labelPlacement="outside" value={vCpus} onValueChange={setVCpus} type="number" ></Input>
          <Input className="w-24" label="VMemory" labelPlacement="outside" value={vMemory} onValueChange={setVMemory} type="number" 
            endContent=
            {
              <div className="pointer-events-none flex items-center">
                <span className="text-default-400 text-small">GB</span>
              </div>
            }
          ></Input>
          <Checkbox className="pt-8" isSelected={bridged} onValueChange={setBridged} >Bridged Connection</Checkbox>
          <Input className="w-32" label="Device Name" value={networkDevice} onValueChange={setNetworkDevice} type="text" labelPlacement="outside"></Input>
        </div>
        <Button color="primary" type="button" onPress={callCreateVmFromIsoImage}>Create VM</Button>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div>
        <Button color="primary" type="button" onPress={logout}>Log Out...</Button>
      </div>
    </div>
  );
}
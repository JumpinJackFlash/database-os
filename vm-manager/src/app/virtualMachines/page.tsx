'use client'

import { getVMSeedImages, getVirtualMachines, startVirtualMachine, stopVirtualMachine, terminateUserSession, undefineVirtualMachine } from "@/utls/serverActions";
import { Button, Divider } from "@nextui-org/react";
import { useRouter } from "next/navigation";
import { useState, useEffect, useCallback } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell, getKeyValue } from "@nextui-org/table";
import {Select, SelectSection, SelectItem} from "@nextui-org/select";

export default function VirtualMachinesPage(props: any) 
{
  const [ virtualMachines, setVirtualMachines ] = useState([ { vmId: 1, machineName: '', osVariant: ''}]);
  const [ isoSeedImages, setIsoSeedImages ] = useState([ { objectId: 1, objectName: '', fileExtension: '', creationDate: '' } ]);
  const [ qcow2SeedImages, setQcow2SeedImages ] = useState([ { objectId: 1, objectName: '', fileExtension: '', creationDate: '' } ]);

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'action', label: 'Action' }
  ];

  const router = useRouter();

  type VirtualMachineT = (typeof virtualMachines)[0];

  function logout()
  {
    terminateUserSession().then((response) =>
    {
      console.log(response);
      if (response.ok) router.push('/login');
    });
  }

  useEffect(() =>
  {
    getVirtualMachines().then((response) =>
    {
      if (!response.ok && 403 === response.httpStatus) router.push('/login');
      if (response.ok) setVirtualMachines(response.jsonData.virtualMachines);
    });

    getVMSeedImages('iso').then((response) =>
    {
      if (!response.ok && 403 === response.httpStatus) router.push('/login');
      console.log(response);
      setIsoSeedImages(response.jsonData.vaultObjects);
    });

    getVMSeedImages('qcow2').then((response) =>
    {
      if (!response.ok && 403 === response.httpStatus) router.push('/login');
      setQcow2SeedImages(response.jsonData.vaultObjects);
    });
      
  }, []);

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
            <Button onClick={startVirtualMachineHandler.bind(startVirtualMachineHandler, vmId)} >Start VM</Button>
            <Button onClick={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, vmId)} >Stop VM</Button>
            <Button onClick={undefineVirtualMachineHandler.bind(undefineVirtualMachineHandler, vmId)} >Undefine VM</Button>
          </div>);

      default:
        return cellValue;
    }
  }, []);

  return (
    <>
      <div className="container max-w-screen-md p-4">
        <p>Virtual Machines...</p>
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
      <div className="container max-w-screen-md p-4">
        <p>Create an ISO based VM Image...</p>
        <div className="flex w-full flex-wrap md:flex-nowrap gap-4">
          <Select className="max-w-xs" label="Select a seed image">
            {isoSeedImages.map((isoSeedImage) => 
            (
              <SelectItem key={isoSeedImage.objectId}>{isoSeedImage.objectName + ' - ' + isoSeedImage.fileExtension}</SelectItem>
            ))}
          </Select>
        </div>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div className="container max-w-screen-md p-4">
        <p>Create a Cloud-Init based VM Image...</p>
        <div className="flex w-full flex-wrap md:flex-nowrap gap-4">
          <Select className="max-w-xs" label="Select a seed image">
            {qcow2SeedImages.map((qcow2SeedImage) => 
            (
              <SelectItem key={qcow2SeedImage.objectId}>{qcow2SeedImage.objectName + ' - ' + qcow2SeedImage.fileExtension}</SelectItem>
            ))}
          </Select>
        </div>
      </div>
      <Divider className="m-4 max-w-screen-md" />
      <div className="p-4" >
        <Button color="primary" type="button" onClick={logout}>Log Out...</Button>
      </div>
    </>
  );
}
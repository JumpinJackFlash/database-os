'use client'

import {NextUIProvider} from "@nextui-org/system";
import { getListOfVirtualMachines, startVirtualMachine, stopVirtualMachine, terminateUserSession } from "@/utls/serverActions";
import { Button } from "@nextui-org/react";
import { useRouter } from "next/navigation";
import { useState, useEffect, useCallback } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell, getKeyValue } from "@nextui-org/table";

export default function VirtualMachinesPage(props: any) 
{
  const [ virtualMachines, setVirtualMachines ] = useState([ { vmId: 1, machineName: '', osVariant: ''}]);

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
    getListOfVirtualMachines().then((response) =>
    {
      console.log(response.jsonData.virtualMachines);
      console.log(response);
      if (response.ok) setVirtualMachines(response.jsonData.virtualMachines);
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

  const renderCell = useCallback((virtualMachine: VirtualMachineT, columnKey: React.Key, vmId: number) => 
  {
    const cellValue = virtualMachine[columnKey as keyof VirtualMachineT];
    console.log('virtualMachineId: ' + vmId);
    switch (columnKey) 
    {
      case 'action':
        return(<div><Button onClick={startVirtualMachineHandler.bind(startVirtualMachineHandler, vmId)} >Start VM</Button><Button onClick={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, vmId)} >Stop VM</Button></div>);

      default:
        return cellValue;
    }
  }, []);

  return (
    <NextUIProvider>
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
      <div>
      <Button className="w-full" color="primary" type="button" onClick={logout}>Log Out...</Button>
      </div>
    </NextUIProvider>
  );
}
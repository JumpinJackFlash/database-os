'use client'

import {NextUIProvider} from "@nextui-org/system";
import { getListOfVirtualMachines, terminateUserSession } from "@/utls/serverActions";
import { Button } from "@nextui-org/react";
import { useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell, getKeyValue } from "@nextui-org/table";

export default function VirtualMachinesPage(props: any) 
{
  const [ virtualMachines, setVirtualMachines ] = useState([ { vmId: 1, machineName: '', osVariant: ''}]);

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name'},
    { key: 'osVariant', label: 'O/S Variant'}
  ];

  const router = useRouter();

  function logout()
  {
    terminateUserSession().then((response) =>
    {
      if (response.ok) router.push('/login');
    });
  }

  useEffect(() =>
  {
    getListOfVirtualMachines().then((response) =>
    {
      if (response.ok) setVirtualMachines(response.jsonData.virtualMachines);
    });
  }, []);

  return (
    <NextUIProvider>
      <div>
      <Table aria-label="List of Virtual Machines">
        <TableHeader columns={vmColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
        <TableBody items={virtualMachines}>        
          {(item) => (
          <TableRow key={item.vmId}>
            {(columnKey) => <TableCell>{getKeyValue(item, columnKey)}</TableCell>}
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
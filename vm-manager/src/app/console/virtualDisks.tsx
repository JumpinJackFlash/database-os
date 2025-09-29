'use client'

import React, { useState, useContext, useCallback } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { VirtualDiskT, VirtualDisksT } from "@/utils/dataTypes";

interface VirtualDisksPropsI
{
  virtualDisks: VirtualDisksT;
}

export default function VirtualDisks({ virtualDisks }: VirtualDisksPropsI)
{
  const virtualDiskColumns =
  [
    { key: 'diskName', label: 'Disk Name'},
    { key: 'diskSize', label: 'Size'},
    { key: 'sparseAllocation', label: 'Sparse'}
  ];

  const renderVDiskCell = useCallback((virtualDisk: VirtualDiskT, columnKey: React.Key, virtualDiskId: number) => 
    {
      const cellValue = virtualDisk[columnKey as keyof VirtualDiskT];
      return (<div>{cellValue}</div>);
/*      switch (columnKey) 
      {
        case 'diskName':
          return (<div>cellValue</div>);

        case 'diskSize'
          return(
            <div>
              { ('stopped' === virtualMachine.status || 'crashed' === virtualMachine.status) &&
                <Button color='success' onPress={startVirtualMachineHandler.bind(startVirtualMachineHandler, virtualMachineId)} >Start VM</Button>
              }
              { 'running' === virtualMachine.status &&
                <Button color='danger' onPress={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, virtualMachineId)} >Stop VM</Button>
              }
              <Button onPress={showVmDetails.bind(showVmDetails, virtualMachine)} >Details</Button>
            </div>);
  
        case 'status':
          if ('stopped' === virtualMachine.status) return (<div style={{ color: 'red', fontWeight: 'bold'}}>{cellValue}</div>);
          if ('running' === virtualMachine.status) return (<p style={{ color: 'green', fontWeight: 'bold'}}>{cellValue}</p>);
          if ('crashed' === virtualMachine.status) return (<p style={{ color: 'blue', fontWeight: 'bold'}}>{cellValue}</p>);
          return (<p style={{ fontWeight: 'bold'}}>{cellValue}</p>);
  
        default:
          return cellValue;
      } */
    }, []);

  return(
    <>
      <p className="pb-6" ><b>Storage Pool</b></p>
      <div>
        <Table aria-label="List of Virtual Machines">
          <TableHeader columns={virtualDiskColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
          <TableBody items={virtualDisks}>        
          {(item) => 
          (
            <TableRow key={item?.virtualDiskId}>
            { /* @ts-ignore - typescript is a fuckin' PITA.... */ }
              {(columnKey) => <TableCell>{renderVDiskCell(item, columnKey, item?.virtualDiskId)}</TableCell>}
            </TableRow>
          )}
          </TableBody>
        </Table>
      </div>
    </>
  );
}
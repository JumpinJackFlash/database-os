'use client'

import { startVirtualMachine, stopVirtualMachine, deleteVirtualMachine, undefineVirtualMachine } from "@/utils/serverFunctions";
import { Checkbox,  Button } from "@heroui/react";
import React, { useState, useCallback } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { VirtualMachinesT, SetSpinnerSpinning, SetSpinnerText, RefreshVirtualMachineListT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import {  Modal,  ModalContent,  ModalHeader,  ModalBody,  ModalFooter, useDisclosure } from "@heroui/modal";

interface VirtualMachinePropsI 
{
  vmImages: VirtualMachinesT;
  setSpinnerSpinning: SetSpinnerSpinning;
  setSpinnerText: SetSpinnerText;
  refreshVirtualMachineList: RefreshVirtualMachineListT
};

export default function VirtualMachines({ vmImages, setSpinnerSpinning, setSpinnerText, refreshVirtualMachineList }: VirtualMachinePropsI) 
{
  const {isOpen, onOpen, onOpenChange} = useDisclosure();

  const [ deleteVmConfirmed, setDeleteVmConfirmed ] = useState(false);
  const [ deleteBootDiskConfirmed, setDeleteBootDiskConfirmed ] = useState(false);
  const [ deleteThisVM, setDeleteThisVM ] = useState<VirtualMachineT | undefined>(undefined);

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'action', label: 'Action' }
  ];

  type VirtualMachineT = (typeof vmImages)[0];

  function confirmDeleteVM(virtualMachine: VirtualMachineT)
  {
    setDeleteVmConfirmed(false);
    setDeleteBootDiskConfirmed(false);
    setDeleteThisVM(virtualMachine);
    onOpen();
  }

  function deleteVM(onClose: Function, action: string)
  {
    setSpinnerText('Deleting VM....');
    setSpinnerSpinning(true);
    if ('confirmed' === action && undefined !== deleteThisVM)
    {
      deleteVirtualMachine(deleteThisVM?.virtualMachineId, deleteBootDiskConfirmed).then((response) =>
      {
        if (response.ok)
        { 
          addToast({ color: "primary", title: "VM Deleted"});
          refreshVirtualMachineList();
        }
        else
        {
          console.log(response);
        }

        setSpinnerSpinning(false);
        onClose();
      });
    }
    else
      onClose();
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
            <Button onPress={confirmDeleteVM.bind(confirmDeleteVM, virtualMachine)} >Delete VM</Button>
          </div>);

      default:
        return cellValue;
    }
  }, []);

  function startVirtualMachineHandler(virtualMachineId: number)
  {
    setSpinnerText('Starting VM....');
    setSpinnerSpinning(true);
    startVirtualMachine(virtualMachineId).then((response) =>
    {
      if (response.ok) addToast({ title: "VM Started", color: 'primary' });
      setSpinnerSpinning(false);
      console.log(response);
    })
  }

  function stopVirtualMachineHandler(virtualMachineId: number)
  {
    setSpinnerText('Stopping VM....');
    setSpinnerSpinning(true);
    stopVirtualMachine(virtualMachineId).then((response) =>
    {
      if (response.ok) addToast({ color: 'primary', title: "VM Stopped" });
      setSpinnerSpinning(false);
      console.log(response);
    })
  }

  function undefineVirtualMachineHandler(virtualMachineId: number)
  {
    undefineVirtualMachine(virtualMachineId).then((response) =>
    {
      if (response.ok) addToast({ color: 'primary', title: "VM Undefined" });
      console.log(response);
    })
  }

  return (
    <>
      <Modal isOpen={isOpen} onOpenChange={onOpenChange} size="lg">
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">Delete Virtual Machine</ModalHeader>
              <ModalBody>
                <div className="columns-2 flex gap-1">
                  <div>Are you sure you want to delete this Virtual Machine: </div>
                  <div><b>{deleteThisVM?.machineName}</b></div>
                </div>
                <div>
                  <Checkbox isSelected={deleteVmConfirmed} onValueChange={setDeleteVmConfirmed}>Delete the VM?</Checkbox>
                </div>
                { deleteThisVM?.virtualDiskId !== null &&
                  <div>
                    <Checkbox isSelected={deleteBootDiskConfirmed} onValueChange={setDeleteBootDiskConfirmed}>Delete the boot disk?</Checkbox>
                  </div>
                }
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={deleteVM.bind(deleteVM, onClose, 'canceled')}>
                  Close
                </Button>
                <Button color="primary" isDisabled={!deleteVmConfirmed} onPress={deleteVM.bind(deleteVM, onClose, 'confirmed')}>
                  Action
                </Button>
              </ModalFooter>
            </>              
          )}
        </ModalContent>
      </Modal>
      <p className="pb-6" ><b>Virtual Machines...</b></p>
      <div>
        <Table aria-label="List of Virtual Machines">
          <TableHeader columns={vmColumns}>{(column) => <TableColumn key={column.key}>{column.label}</TableColumn>}</TableHeader>
          <TableBody items={vmImages}>        
          {(item) => 
          (
            <TableRow key={item.virtualMachineId}>
              {(columnKey) => <TableCell>{renderVmCell(item, columnKey, item.virtualMachineId)}</TableCell>}
            </TableRow>
          )}
          </TableBody>
        </Table>
        <Button color="primary" onPress={refreshVirtualMachineList}>Refresh</Button>
      </div>
    </>
  );
}
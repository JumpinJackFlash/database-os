'use client'

import { startVirtualMachine, stopVirtualMachine, deleteVirtualMachine, undefineVirtualMachine } from "@/utils/serverFunctions";
import { Checkbox,  Button } from "@heroui/react";
import React, { useState, useCallback, useEffect, useContext } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { VirtualMachinesT, RefreshVirtualMachineListT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import {  Modal,  ModalContent,  ModalHeader,  ModalBody,  ModalFooter, useDisclosure } from "@heroui/modal";
import { VmManagerContext } from "@/utils/vmManagerContext";

interface VirtualMachinePropsI 
{
  vmImages: VirtualMachinesT;
  refreshVirtualMachineList: RefreshVirtualMachineListT
};

export default function VirtualMachines({ vmImages, refreshVirtualMachineList }: VirtualMachinePropsI) 
{
  const {isOpen, onOpen, onOpenChange} = useDisclosure();

  const { isOpen: isDetailModalOpen, onOpen: onDetailModalOpen, onOpenChange: onDetailModalOpenChange, 
    onClose: onDetailModalClose } = useDisclosure();
  
  const [ deleteVmConfirmed, setDeleteVmConfirmed ] = useState(false);
  const [ deleteBootDiskConfirmed, setDeleteBootDiskConfirmed ] = useState(false);
  const [ deleteThisVM, setDeleteThisVM ] = useState<VirtualMachineT | undefined>(undefined);
  const [ selectedVM, setSelectedVm ] = useState<VirtualMachineT | undefined>(undefined);

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'host', label: 'Host' },
    { key: 'status', label: 'Status'},
    { key: 'action', label: 'Action' }
  ];

  type VirtualMachineT = (typeof vmImages)[0];

  const vmManagerContext = useContext(VmManagerContext);

/*  useEffect(() =>
  {
    var intervalId: any;

    intervalId = setInterval(() =>
    {
      refreshVirtualMachineList();
    }, 5000);

    return () =>
    {
      if (undefined !== intervalId) clearInterval(intervalId);
    }
  }, []); */

  function confirmDeleteVM(virtualMachine: VirtualMachineT)
  {
    setDeleteVmConfirmed(false);
    setDeleteBootDiskConfirmed(false);
    setDeleteThisVM(virtualMachine);
    onOpen();
  }

  function deleteVM(onClose: Function, action: string)
  {
    if ('confirmed' === action && undefined !== deleteThisVM)
    {
      vmManagerContext?.setSpinnerState(true, 'Deleting VM....');
      deleteVirtualMachine(deleteThisVM?.virtualMachineId, deleteBootDiskConfirmed).then((response) =>
      {
        vmManagerContext?.setSpinnerState(false);
        if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
        addToast({ color: "primary", title: "VM Deleted"});
        refreshVirtualMachineList();
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
            { ('stopped' === virtualMachine.status || 'crashed' === virtualMachine.status) &&
              <Button color='success' onPress={startVirtualMachineHandler.bind(startVirtualMachineHandler, virtualMachineId)} >Start VM</Button>
            }
            { 'running' === virtualMachine.status &&
              <Button color='danger' onPress={stopVirtualMachineHandler.bind(stopVirtualMachineHandler, virtualMachineId)} >Stop VM</Button>
            }
            <Button onPress={undefineVirtualMachineHandler.bind(undefineVirtualMachineHandler, virtualMachineId)} >Details</Button>
            <Button onPress={undefineVirtualMachineHandler.bind(undefineVirtualMachineHandler, virtualMachineId)} >Undefine VM</Button>
          </div>);

      case 'status':
        if ('stopped' === virtualMachine.status) return (<div style={{ color: 'red', fontWeight: 'bold'}}>{cellValue}</div>);
        if ('running' === virtualMachine.status) return (<p style={{ color: 'green', fontWeight: 'bold'}}>{cellValue}</p>);
        if ('crashed' === virtualMachine.status) return (<p style={{ color: 'blue', fontWeight: 'bold'}}>{cellValue}</p>);
        return (<p style={{ fontWeight: 'bold'}}>{cellValue}</p>);
      default:
        return cellValue;
    }
  }, []);

  function startVirtualMachineHandler(virtualMachineId: number)
  {
    vmManagerContext?.setSpinnerState(true, 'Starting VM....');
    startVirtualMachine(virtualMachineId).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ title: "VM Started", color: 'primary' });
      refreshVirtualMachineList();
    })
  }

  function stopVirtualMachineHandler(virtualMachineId: number)
  {
    vmManagerContext?.setSpinnerState(true, 'Stopping VM....');
    stopVirtualMachine(virtualMachineId).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: 'primary', title: "VM Stopped" });
      refreshVirtualMachineList();
    })
  }

  function undefineVirtualMachineHandler(virtualMachineId: number)
  {
    undefineVirtualMachine(virtualMachineId).then((response) =>
    {
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: 'primary', title: "VM Undefined" });
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
                  Cancel
                </Button>
                <Button color="primary" isDisabled={!deleteVmConfirmed} onPress={deleteVM.bind(deleteVM, onClose, 'confirmed')}>
                  Delete
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
      </div>
    </>
  );
}
/*              <Button color='danger' onPress={confirmDeleteVM.bind(confirmDeleteVM, virtualMachine)} >Delete VM</Button> */

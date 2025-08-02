'use client'

import { startVirtualMachine, stopVirtualMachine } from "@/utils/serverFunctions";
import React, { useState, useCallback, useEffect, useContext } from "react";
import { Table,  TableHeader,  TableBody,  TableColumn,  TableRow,  TableCell } from "@heroui/table";
import { VirtualMachinesT, VirtualMachineT, RefreshVirtualMachineListT } from "@/utils/dataTypes";
import { Button, addToast } from "@heroui/react";
import {  Modal,  ModalContent,  ModalHeader,  ModalFooter, useDisclosure } from "@heroui/modal";

import VirtualMachineDetails from './virtualMachineDetails';

import { VmManagerContext } from "@/utils/vmManagerContext";

interface VirtualMachinesPropsI 
{
  vmImages: VirtualMachinesT;
  refreshVirtualMachineList: RefreshVirtualMachineListT
};

export default function VirtualMachines({ vmImages, refreshVirtualMachineList }: VirtualMachinesPropsI) 
{
  const { isOpen: isDetailModalOpen, onOpen: openDetailModal, onOpenChange: openDetailModalChange, 
    onClose: closeDetailModal } = useDisclosure();
  
  const [ selectedVM, setSelectedVm ] = useState<VirtualMachineT>();

  const vmColumns =
  [
    { key: 'machineName', label: 'Machine Name' },
    { key: 'osVariant', label: 'O/S Variant' },
    { key: 'host', label: 'Host' },
    { key: 'status', label: 'Status'},
    { key: 'action', label: 'Action' }
  ];

  const vmManagerContext = useContext(VmManagerContext);

  useEffect(() =>
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
  }, []);

  function showVmDetails(virtualMachine: VirtualMachineT)
  {
    setSelectedVm(virtualMachine);
    openDetailModal();
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
            <Button onPress={showVmDetails.bind(showVmDetails, virtualMachine)} >Details</Button>
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

  return (
    <>
      <Modal isOpen={isDetailModalOpen} onOpenChange={openDetailModalChange} size="4xl">
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">Virtual Machine Details</ModalHeader>
              { selectedVM !== undefined &&

                <VirtualMachineDetails virtualMachine={selectedVM} refreshVirtualMachineList={refreshVirtualMachineList} />
              }
              <ModalFooter>
                <Button variant="light" onPress={closeDetailModal}>Close</Button>
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
            <TableRow key={item?.virtualMachineId}>
            { /* @ts-ignore - typescript is a fuckin' PITA.... */ }
              {(columnKey) => <TableCell>{renderVmCell(item, columnKey, item?.virtualMachineId)}</TableCell>}
            </TableRow>
          )}
          </TableBody>
        </Table>
      </div>
    </>
  );
}
/*              <Button color='danger' onPress={confirmDeleteVM.bind(confirmDeleteVM, virtualMachine)} >Delete VM</Button> */

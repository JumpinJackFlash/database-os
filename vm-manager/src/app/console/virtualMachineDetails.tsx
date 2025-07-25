'use client'

import { formatTimestamp } from "@/utils/clientFunctions";
import { startVirtualMachine, stopVirtualMachine, deleteVirtualMachine, undefineVirtualMachine } from "@/utils/serverFunctions";
import { Checkbox,  Button } from "@heroui/react";
import React, { useState, useContext } from "react";
import { VirtualMachineT, RefreshVirtualMachineListT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import { ModalBody, useDisclosure } from "@heroui/modal";
import { Input } from '@heroui/react'

import { VmManagerContext } from "@/utils/vmManagerContext";

interface VirtualMachinePropsI 
{
  virtualMachine: VirtualMachineT;
  refreshVirtualMachineList: RefreshVirtualMachineListT
};

export default function VirtualMachines({ virtualMachine, refreshVirtualMachineList }: VirtualMachinePropsI)
{
  const { isOpen: isDetailModalOpen, onOpen: openDetailModal, onOpenChange: openDetailModalChange, 
    onClose: closeDetailModal } = useDisclosure();
  
  const [ vCpus, setVCpus ] = useState(String(virtualMachine.vCpuCount));
  const [ vMemory, setVMemory ] = useState(String(virtualMachine.virtualMemory / 1024));
  const [ deleteVmConfirmed, setDeleteVmConfirmed ] = useState(false);
  const [ deleteBootDiskConfirmed, setDeleteBootDiskConfirmed ] = useState(false);
  const [ persistentVM, setPersistentVM ] = useState('Y' === virtualMachine.persistent ? true : false);

  const vmManagerContext = useContext(VmManagerContext);

  function deleteVM()
  {
    vmManagerContext?.setSpinnerState(true, 'Deleting VM....');
    deleteVirtualMachine(virtualMachine?.virtualMachineId, deleteBootDiskConfirmed).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: "primary", title: "VM Deleted"});
      refreshVirtualMachineList();
      closeDetailModal();
    });
  }

  const immutableFieldsText = virtualMachine?.status !== 'stopped' ? 'Running instance - fields are immutable' : '';
  const inputDisabled = virtualMachine?.status !== 'stopped' ? true : false;
  const deleteDisabledText = virtualMachine?.status !== 'stopped' ? 'Running instance must be stopped first.' : '';

  function setPersistence(setting: boolean)
  {
    setPersistentVM(setting);
    if (!setting && 'running' === virtualMachine.status)
    {
      undefineVirtualMachine(virtualMachine.virtualMachineId).then((response) =>
      {
        if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
        addToast({ color: 'primary', title: "VM Undefined" });
      })
    }

  }

  function undefineVirtualMachineHandler(virtualMachineId: number)
  {
    undefineVirtualMachine(virtualMachineId).then((response) =>
    {
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: 'primary', title: "VM Undefined" });
    })
  }

  console.log(virtualMachine);
  return(
    <ModalBody>
      <div className="columns-3 flex gap-5">
        <b>Machine Name: {virtualMachine.machineName}</b>
        <p>O/S Variant: {virtualMachine.osVariant}</p>
        <p>UUID: {virtualMachine.uuid}</p>
      </div>
      <div className="columns-3 flex gap-5">
        <p>Host: {virtualMachine?.host}</p>
        { virtualMachine.creationTimestamp !== undefined &&
          <p>Creation Date: {formatTimestamp(virtualMachine.creationTimestamp, true)}</p>
        }
        <p>Status: {virtualMachine.status}</p>
      </div>
      <div className="columns-3 flex gap-5">
        <p>Network Source: {virtualMachine.networkSource}</p>
        <p>Network Device: {virtualMachine.networkDevice}</p>
        <p>Interfaces: {JSON.stringify(virtualMachine.interfaces)}</p>
      </div>
      <div>
        <Checkbox title="Persistent VM's remain defined in the host's VM Manager Interface" isSelected={persistentVM} onValueChange={setPersistence} >Persistent VM</Checkbox>
      </div>
      <div className="columns-2 flex gap-1" title={immutableFieldsText}>
        <Input disabled={inputDisabled} className="w-24" label="VCPU's" labelPlacement="outside" value={vCpus} onValueChange={setVCpus} type="number"  min={1}></Input>
        <Input disabled={inputDisabled} className="w-24" label="VMemory" labelPlacement="outside" value={vMemory} onValueChange={setVMemory} type="number"  min={1}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
      </div>
      <div title={deleteDisabledText}>
        <Checkbox isDisabled={inputDisabled} title={deleteDisabledText} isSelected={deleteVmConfirmed} onValueChange={setDeleteVmConfirmed}>Delete the VM?</Checkbox>
      </div>
      <div title={deleteDisabledText}>
        <Checkbox isDisabled={inputDisabled} isSelected={deleteBootDiskConfirmed} onValueChange={setDeleteBootDiskConfirmed}>Delete the boot disk?</Checkbox>
      </div>
      <div title={deleteDisabledText}>
        <Button color="danger" isDisabled={!deleteVmConfirmed} onPress={deleteVM}>Delete</Button>
      </div>
    </ModalBody>
  );
}
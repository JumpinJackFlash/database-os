'use client'

import VirtualMachines from './virtualMachines';
import CreateVM from "./createVM";

import { getVirtualMachines, terminateUserSession } from "@/utils/serverFunctions";
import { Button, Divider } from "@heroui/react";
import { useRouter } from "next/navigation";
import React, { useState } from "react";
import { OsVariantsT, SeedImagesT, VirtualMachinesT, VmHostsT } from "@/utils/dataTypes";
import {Spinner} from "@heroui/spinner";
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter, useDisclosure} from "@heroui/modal";
import { VmManagerContext } from "@/utils/vmManagerContext";

interface ConsolePropsI 
{
  osVariants: OsVariantsT;
  isoImages: SeedImagesT;
  qcow2Images: SeedImagesT;
  vmImages: VirtualMachinesT;
  vmHosts: VmHostsT;
};

export default function Console({ osVariants, isoImages, qcow2Images, vmImages, vmHosts }: ConsolePropsI) 
{
  const [ virtualMachines, setVirtualMachines ] = useState(vmImages);

  const [ spinnerSpinning, setSpinnerSpinning ] = useState(false);
  const [ spinnerText, setSpinnerText ] = useState('');

  const {isOpen: isErrorModalOpen, onOpen: onErrorModalOpen, onOpenChange: onErrorModalOpenChange,
    onClose: onErrorModalClose } = useDisclosure();

  const [ errorMessage, setErrorMessage ] = useState('');

  const {isOpen: isCreateVmModalOpen, onOpen: onCreateVmModalOpen, onOpenChange: onCreateVmModalOpenChange,
    onClose: onCreateVmModalClose } = useDisclosure();

  const router = useRouter();
  
  function logout()
  {
    terminateUserSession().then((response) =>
    {
      if (!response.ok) showErrorModal(response.jsonData.errorMessage)
      router.push('/deleteCookie');
    });
  }

  function refreshVirtualMachineList()
  {
    getVirtualMachines().then((response) =>
    {
      if (!response.ok) return showErrorModal(response.jsonData.errorMessage)
      setVirtualMachines(response.jsonData.virtualMachines);
    }); 
  }

  function setSpinnerState(spinning: boolean, spinnerText?: string)
  {
    setSpinnerSpinning(spinning);
    if (undefined !== spinnerText) setSpinnerText(spinnerText);
  }

  function showErrorModal(errorMessage: string)
  {
    setErrorMessage(errorMessage);
    onErrorModalOpen();
  }

  let contextValue = { setSpinnerState: setSpinnerState, showErrorModal: showErrorModal }

  return (
    <VmManagerContext.Provider value={contextValue}>
      <Modal isOpen={isErrorModalOpen} onOpenChange={onErrorModalOpenChange} size="lg">
        <ModalContent>
          {(onErrorModalClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">API Error</ModalHeader>
              <ModalBody>
                <p>{errorMessage}</p>
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onErrorModalClose}>
                  Close
                </Button>
                <Button color="primary" onPress={onErrorModalClose}>
                  Action
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>                
      <Modal isOpen={isCreateVmModalOpen} onOpenChange={onCreateVmModalOpenChange} size="5xl">
        <ModalContent>
          {(onCreateVmModalClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">Create a New VM</ModalHeader>
              <ModalBody>
                <CreateVM osVariants={osVariants} qcow2Images={qcow2Images} isoImages={isoImages} refreshVirtualMachineList={refreshVirtualMachineList} vmHosts={vmHosts}/>
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onCreateVmModalClose}>
                  Close
                </Button>
                <Button color="primary" onPress={onCreateVmModalClose}>
                  Action
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>                
      { spinnerSpinning &&
        <div style={{position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)"}}>
          <Spinner color="primary" label={spinnerText} />
        </div>
      }
      <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
        <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
          <VirtualMachines vmImages={virtualMachines} refreshVirtualMachineList={refreshVirtualMachineList} />
          <div>
            <Button color="primary" onPress={refreshVirtualMachineList}>Refresh</Button>
            <Button color="success" onPress={onCreateVmModalOpen}>New VM</Button>
          </div>
          <Divider className="m-4 max-w-screen-md" />
          <div>
            <Button color="primary" type="button" onPress={logout}>Log Out...</Button>
          </div>
        </div>
      </div>
    </VmManagerContext.Provider>
  );
}
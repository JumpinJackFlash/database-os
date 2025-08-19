'use client'

import  CreateQcowVM  from './createQcowVM';
import  CreateIsoVM  from './createIsoVM';

import { createVmFromIsoImage, createQcowVmFromTemplate, createQcowVmUsingConfigFiles } from "@/utils/serverFunctions";
import { Card, CardBody, Tabs, Tab, Button } from "@heroui/react";
import { useRouter } from "next/navigation";
import React, { useState, useContext, useCallback, FocusEvent, ChangeEvent } from "react";
import { OsVariantsT, SeedImagesT, NameserverT, SshKeyT, SetIpCallbackT, RefreshVirtualMachineListT, VmHostsT, AttachedStorageT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import { VmManagerContext } from "@/utils/vmManagerContext";

interface CreateVMPropsI 
{
  osVariants: OsVariantsT;
  isoImages: SeedImagesT;
  qcow2Images: SeedImagesT;
  refreshVirtualMachineList: RefreshVirtualMachineListT;
  vmHosts?: VmHostsT
};

export default function CreateVM({ osVariants, isoImages, qcow2Images, refreshVirtualMachineList, vmHosts }: CreateVMPropsI) 
{
  const vmManagerContext = useContext(VmManagerContext);

  return (
    <div>
      <Tabs aria-label="Options">
        <Tab key="iso" title="Create From an ISO Seed">
          <Card>
            <CardBody>
              <CreateIsoVM osVariants={osVariants} isoImages={isoImages} refreshVirtualMachineList={refreshVirtualMachineList} vmHosts={vmHosts}/>
            </CardBody>
          </Card>
        </Tab>
        <Tab key="qcow" title="Create From a QCOW2 Seed">
          <Card>
            <CardBody>
              <CreateQcowVM osVariants={osVariants} qcow2Images={qcow2Images} refreshVirtualMachineList={refreshVirtualMachineList} vmHosts={vmHosts}/>
            </CardBody>
          </Card>
        </Tab>
      </Tabs>
    </div>
  );
}
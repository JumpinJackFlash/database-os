'use client'

import { createVmFromIsoImage } from "@/utils/serverFunctions";
import { Checkbox, Input, Button, Autocomplete, AutocompleteItem, Divider } from "@heroui/react";
import React, { useState, useContext, ChangeEvent } from "react";
import { Select, SelectItem } from "@heroui/select";
import { OsVariantsT, SeedImagesT, RefreshVirtualMachineListT, VmHostsT, AttachedStorageT } from "@/utils/dataTypes";
import { addToast } from "@heroui/react";
import { VmManagerContext } from "@/utils/vmManagerContext";

interface CreateIsoVMPropsI 
{
  osVariants: OsVariantsT;
  isoImages: SeedImagesT;
  refreshVirtualMachineList: RefreshVirtualMachineListT;
  vmHosts?: VmHostsT
};

export default function CreateIsoVM({ osVariants, isoImages, refreshVirtualMachineList, vmHosts }: CreateIsoVMPropsI) 
{
  const [ isoImage, setIsoImage ] = useState('');
  const [ isoVmImageName, setIsoVmImageName ] = useState('');
  const [ isoOsVariantId, setIsoOsVariantId ] = useState<React.Key | null>('');
  const [ bootDiskSize, setBootDiskSize ] = useState('5');
  const [ isoVCpus, setIsoVCpus ] = useState('2');
  const [ isoVMemory, setIsoVMemory ] = useState('2');
  const [ isoBridged, setIsoBridged ] = useState(false);
  const [ isoNetworkDevice, setIsoNetworkDevice ] = useState('default');

  const [ diskSize, setDiskSize ] = useState('0');
  const [ diskLabel, setDiskLabel ] = useState('');

  const [ vmHostId, setVmHostId ] = useState('');

  const vmManagerContext = useContext(VmManagerContext);

  function callCreateVmFromIsoImage()
  {
    let attachedStorage: []|[AttachedStorageT] = [];

    if (parseInt(diskSize))
    {
      attachedStorage = [{ diskLabel, diskSize: parseInt(diskSize) }];
    }

    vmManagerContext?.setSpinnerState(true, 'Creating VM....');
    createVmFromIsoImage(isoVmImageName, isoImage, parseInt(isoOsVariantId as string), vmHostId, parseInt(bootDiskSize), 'Y', 
      parseInt(isoVCpus), parseInt(isoVMemory), isoBridged ? 'Y' : 'N', isoNetworkDevice, attachedStorage).then((response) =>
    {
      vmManagerContext?.setSpinnerState(false);
      if (!response.ok) return vmManagerContext?.showErrorModal(response.jsonData.errorMessage);
      addToast({ color: "primary", title: "VM Created"});
      refreshVirtualMachineList();
    });
  }

  function onChangeHandler(setFunction: React.Dispatch<React.SetStateAction<string>>, event: ChangeEvent<HTMLSelectElement>)
  {
    setFunction(event.target.value);
  }

   return (
    <>
      <div className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4 pt-6 pb-6">
        <Select className="w-80" label="Select an ISO image" onChange={onChangeHandler.bind(onChangeHandler, setIsoImage)} selectedKeys={[isoImage]}>
          {isoImages.map((isoImage) => 
          (
            <SelectItem className={"w-lg"} key={isoImage.objectId}>{isoImage.objectName + ' - ' + isoImage.fileExtension}</SelectItem>
          ))}
        </Select>
        <div>
          <Autocomplete className="max-w-xs" label="Select an os-variant" defaultItems={osVariants} onSelectionChange={setIsoOsVariantId} selectedKey={String(isoOsVariantId)} isVirtualized={true} >
            { (item) => <AutocompleteItem className={"w-lg"} key={item.variantId}>{item.longName}</AutocompleteItem> }
          </Autocomplete>
        </div>
      </div>
      <div  className="columns-2 flex w-full flex-wrap md:flex-nowrap gap-4">
        <Input value={isoVmImageName} onValueChange={setIsoVmImageName} label="VM Image Name"/>
        <Select className="w-80" label="Select a VM Host Server" onChange={onChangeHandler.bind(onChangeHandler, setVmHostId)} selectedKeys={[vmHostId]}>
          {/* @ts-ignore */}
          {vmHosts.map((vmHost) =>
          (
            <SelectItem className={"w-lg"} key={vmHost.hostId}>{vmHost.hostName}</SelectItem>
          ))}
        </Select>
      </div>
      <div className="columns-5 flex gap-4 pt-6 pb-6">
        <Input className="w-32" label="Boot Disk Size" labelPlacement="outside" value={bootDiskSize} onValueChange={setBootDiskSize} type="number" min={1}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
        <Input className="w-24" label="VCPU's" labelPlacement="outside" value={isoVCpus} onValueChange={setIsoVCpus} type="number"  min={1}></Input>
        <Input className="w-24" label="VMemory" labelPlacement="outside" value={isoVMemory} onValueChange={setIsoVMemory} type="number"  min={1}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
        <Checkbox className="pt-8" isSelected={isoBridged} onValueChange={setIsoBridged} >Bridged Connection</Checkbox>
        <Input className="w-32" label="Device Name" value={isoNetworkDevice} onValueChange={setIsoNetworkDevice} type="text" labelPlacement="outside"></Input>
      </div>
      <Divider />
      <div className="pb-6 pt-6 columns-1">Additional Storage</div>
      <div className="columns-2 flex gap-4 pb-6">
        <Input className="w-32" label="Disk Size" labelPlacement="outside" value={diskSize} onValueChange={setDiskSize} type="number" min={0}
          endContent=
          {
            <div className="pointer-events-none flex items-center">
              <span className="text-default-400 text-small">GB</span>
            </div>
          }
        ></Input>
        <Input value={diskLabel} onValueChange={setDiskLabel} label="Volume Name" labelPlacement="outside" type="text"></Input>
      </div>
      <div className="columns-1">
        <Button color="primary" type="button" onPress={callCreateVmFromIsoImage}>Create VM</Button>
      </div>
    </>
  );
}
'use client'

import VirtualMachines from "./virtualMachines";
import CreateVM from "./createVM";

import { getVirtualMachines, terminateUserSession } from "@/utils/serverFunctions";
import { Button, Divider } from "@heroui/react";
import { useRouter } from "next/navigation";
import React, { useState } from "react";
import { OsVariantsT, SeedImagesT, VirtualMachinesT, VmHostsT } from "@/utils/dataTypes";
import {Spinner} from "@heroui/spinner";

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

  const router = useRouter();
  
  function logout()
  {
    terminateUserSession().then((response) =>
    {
      console.log(response);
      if (response.ok) router.push('/deleteCookie');
    });
  }

  function refreshVirtualMachineList()
  {
    getVirtualMachines().then((response) =>
    {
      if (!response.ok)
      {
        console.log(response);
      }
      setVirtualMachines(response.jsonData.virtualMachines);
    }); 
  }

  console.log(vmHosts);

  return (
    <>
      { spinnerSpinning &&
        <div style={{position: "fixed", top: "50%", left: "50%", transform: "translate(-50%, -50%)"}}>
          <Spinner color="primary" label={spinnerText} />
        </div>
      }
      <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
        <div className=" max-w-screen-md flex-col gap-4 rounded-large px-8 pb-10 pt-6">
          <VirtualMachines vmImages={virtualMachines} refreshVirtualMachineList={refreshVirtualMachineList} setSpinnerSpinning={setSpinnerSpinning} setSpinnerText={setSpinnerText} />
          <Divider className="m-4 max-w-screen-md" />
          <CreateVM osVariants={osVariants} qcow2Images={qcow2Images} isoImages={isoImages} refreshVirtualMachineList={refreshVirtualMachineList} 
            setSpinnerSpinning={setSpinnerSpinning} setSpinnerText={setSpinnerText} vmHosts={vmHosts}/>
          <Divider className="m-4 max-w-screen-md" />
          <div>
            <Button color="primary" type="button" onPress={logout}>Log Out...</Button>
          </div>
        </div>
      </div>
    </>
  );
}
import VirtualMachines from './virtualMachines'

import { getOsVariants, getIsoImages, getVirtualMachines } from "@/utls/serverActions";

export default async function Page(props: any) 
{

  const osPromise = getOsVariants();
  const isoPromise = getIsoImages();
  const vmPromise = getVirtualMachines();

  const [ osResult, isoResult, vmResult ] = await Promise.all([ osPromise, isoPromise, vmPromise ]);
  
  return (
    <>
      <VirtualMachines osVariants={osResult.jsonData.osVariants} isoImages={isoResult.jsonData.vaultObjects} virtualMachines={vmResult.jsonData.virtualMachines} />
    </>
  );
}
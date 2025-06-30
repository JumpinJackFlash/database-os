'use server'
import Console from './console'

import { getOsVariants, getIsoSeedImages, getQcow2SeedImages, getVirtualMachines, getVmHosts, ServerResponseT } from "@/utils/serverFunctions";
import { redirect } from 'next/navigation'

export default async function VirtualMachinesPage() 
{
  const osPromise = getOsVariants();
  const isoPromise = getIsoSeedImages();
  const qcow2Promise = getQcow2SeedImages();
  const vmPromise = getVirtualMachines();
  const vmHostsPromise = getVmHosts();

  function apiErrorHandler(response: ServerResponseT)
  {
    console.log('wtf...!!!');
    console.log(response);
    if (403 === response.httpStatus) return redirect('/deleteCookie');
  }

  const [ osResponse, isoResponse, qcow2Response, vmResponse, vmHostsResponse ] = await Promise.all([ osPromise, isoPromise, qcow2Promise, vmPromise, vmHostsPromise ]);
  if (!osResponse.ok || !isoResponse.ok || !qcow2Response.ok || !vmResponse.ok || !vmHostsResponse.ok)
  {
    if (!osResponse.ok) apiErrorHandler(osResponse);
    if (!isoResponse.ok) apiErrorHandler(isoResponse);
    if (!qcow2Response.ok) apiErrorHandler(qcow2Response);
    if (!vmResponse.ok) apiErrorHandler(vmResponse);
    if (!vmHostsResponse.ok) apiErrorHandler(vmHostsResponse);
  }
  
  return (
    <>
      <Console osVariants={osResponse.jsonData.osVariants} isoImages={isoResponse.jsonData.vaultObjects} vmImages={vmResponse.jsonData.virtualMachines} 
        qcow2Images={qcow2Response.jsonData.vaultObjects} vmHosts={vmHostsResponse.jsonData.vmHosts}/>
    </>
  );
}
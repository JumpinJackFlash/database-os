'use server'
import VirtualMachines from './virtualMachines'

import { getOsVariants, getIsoSeedImages, getQcow2SeedImages, getVirtualMachines, ServerResponseT } from "@/utils/serverFunctions";
import { eraseSessionCookie } from '@/utils/coookieMonster';
import { redirect } from 'next/navigation'

export default async function VirtualMachinesPage() 
{
  const osPromise = getOsVariants();
  const isoPromise = getIsoSeedImages();
  const qcow2Promise = getQcow2SeedImages();
  const vmPromise = getVirtualMachines();

  function apiErrorHandler(response: ServerResponseT)
  {
    console.log('wtf...!!!');
    console.log(response);
    if (403 === response.httpStatus) return redirect('/deleteCookie');
  }

  const [ osResponse, isoResponse, qcow2Response, vmResponse ] = await Promise.all([ osPromise, isoPromise, qcow2Promise, vmPromise ]);
  if (!osResponse.ok || !isoResponse.ok || !qcow2Response.ok || !vmResponse.ok)
  {
    if (!osResponse.ok) apiErrorHandler(osResponse);
    if (!isoResponse.ok) apiErrorHandler(isoResponse);
    if (!qcow2Response.ok) apiErrorHandler(qcow2Response);
    if (!vmResponse.ok) apiErrorHandler(vmResponse);
  }
  
  return (
    <>
      <VirtualMachines osVariants={osResponse.jsonData.osVariants} isoImages={isoResponse.jsonData.vaultObjects} vmImages={vmResponse.jsonData.virtualMachines} 
        qcow2Images={qcow2Response.jsonData.vaultObjects} />
    </>
  );
}
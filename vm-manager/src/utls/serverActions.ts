"use server"

import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

const cookieName = 'sessionData';

async function callDbTwig(apiCall: string, body?: any) 
{
  const cookieStore = await cookies();

  var cookieData = cookieStore.get(cookieName);
  var bearerToken = null;
  if (undefined !== cookieData && '' !== cookieData.value)
  {
    const jData = JSON.parse(cookieData.value);
    bearerToken = jData.sessionId;
  }

  var requestOptions = {};
  
  if (undefined !== body)

    requestOptions = 
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + bearerToken },
      body: JSON.stringify(body)
    };
  else
    requestOptions = 
    {
      method: 'GET',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + bearerToken },
    };

  var httpResponse = await fetch(process.env.DB_TWIG_URL + '/' + apiCall, requestOptions);
  const jsonData = await httpResponse.json();
  let response =
  {
    jsonData: jsonData,
    ok: httpResponse.ok,
    httpStatus: httpResponse.status
  }

  if (!response.ok && 403 === response.httpStatus) cookieStore.delete(cookieName);
    
  return response;
}

export async function createVmFromIsoImage(machineName: string, isoImageId: string, osVariantId: number,
  virtualDiskSize: number, sparseDiskAllocation: string, vcpuCount: number, virtualMemory: number,
  bridgedConnection: string, networkDevice: string)
{
  let bodyData = {machineName, isoImageId, osVariantId, virtualDiskSize, sparseDiskAllocation, vcpuCount, 
    virtualMemory, bridgedConnection, networkDevice};

  let response = await callDbTwig('dbos/createVmFromIsoImage', bodyData);
  return response;
}

export async function createUserSession(identification: string, password: string)
{
  let bodyData = { identification, password };
  let response = await callDbTwig('icam/createUserSession', bodyData);
  if (response.ok)
  {
    const cookieStore = await cookies()
    
    cookieStore.set(cookieName, 
      JSON.stringify({sessionId: response.jsonData.sessionId, accountType: response.jsonData.accountType}),
      {
        httpOnly: true,
        secure: true,
        sameSite: 'lax'
      });
  }
  return response;
}

export async function getIsoImages()
{
  const response = await callDbTwig('dbos/getIsoImages');
  return response;
}

export async function getOsVariants()
{
  const response = await callDbTwig('dbos/getOsVariants');
  return response;
}

export async function getServiceData()
{
  const response = await callDbTwig('dbos/getServiceData');
  if (response.ok)
  {
    process.env.JWT_SIGNING_KEY = response.jsonData.jwtSigningKey;
    process.env.JWT_EXPIRES_IN = response.jsonData.jwtExpiresIn;
  }
  return response;
}

export async function getVirtualMachines()
{
  const response = await callDbTwig('dbos/getVirtualMachines')
  return response;
}

export async function startVirtualMachine(vmId: number)
{
  let bodyData = { vmId: vmId };
  let response = await callDbTwig('dbos/startVirtualMachine', bodyData);
  return response;
}

export async function stopVirtualMachine(vmId: number)
{
  let bodyData = { vmId: vmId };
  let response = await callDbTwig('dbos/stopVirtualMachine', bodyData);
  return response;
}

export async function undefineVirtualMachine(vmId: number)
{
  let bodyData = { vmId: vmId };
  let response = await callDbTwig('dbos/undefineVirtualMachine', bodyData);
  return response;
}

export async function terminateUserSession()
{
  const response = await callDbTwig('icam/terminateUserSession');
  if (response.ok) (await cookies()).delete(cookieName);
  return response;
}
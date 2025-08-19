"use server"

import { createSessionCookie, getSessionCookie, deleteSessionCookie } from './coookieMonster'
import { NameserverT, SshKeyT, AttachedStorageT } from './dataTypes'

export type ServerResponseT =
{
  jsonData: string,
  ok: boolean,
  httpStatus: number
}

async function callDbTwig(apiCall: string, body?: object) 
{
  const cookieData = await getSessionCookie();
  let bearerToken = null;
  if (undefined !== cookieData && '' !== cookieData.value)
  {
    const jData = JSON.parse(cookieData.value);
    bearerToken = jData.sessionId;
  }

  let requestOptions = {};
  
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

  const httpResponse = await fetch(process.env.DB_TWIG_URL + '/' + apiCall, requestOptions);
  const jsonData = await httpResponse.json();
  const response =
  {
    jsonData: jsonData,
    ok: httpResponse.ok,
    httpStatus: httpResponse.status
  }

  return response;
}

export async function createVmFromIsoImage(machineName: string, isoImageId: string, osVariantId: number, hostId: string,
  virtualDiskSize: number, sparseDiskAllocation: string, vcpuCount: number, virtualMemory: number,
  bridgedConnection: string, networkDevice: string, attachedStorage: AttachedStorageT[])
{
  const bodyData = {machineName, isoImageId, osVariantId, virtualDiskSize, sparseDiskAllocation, vcpuCount, 
    virtualMemory, bridgedConnection, networkDevice, hostId, attachedStorage};

  const response = await callDbTwig('dbos/createVmFromIsoImage', bodyData);
  return response;
}

export async function createQcowVmUsingConfigFiles(machineName: string, qcowImageId: string, osVariantId: number, 
  hostId: string, vcpuCount: number, virtualMemory: number, bridgedConnection: string, networkDevice: string, 
  metaData: string, userData: string, networkConfig: string, attachedStorage: AttachedStorageT[])
{
  const bodyData = {machineName, qcowImageId, osVariantId, vcpuCount, virtualMemory, bridgedConnection, networkDevice, metaData, userData, 
    networkConfig, attachedStorage, hostId, config: 'files'};

  const response = await callDbTwig('dbos/createVmFromQcowImage', bodyData);
  return response;
}

export async function createQcowVmFromTemplate(machineName: string, qcowImageId: string, osVariantId: number, hostId: string,
  vcpuCount: number, virtualMemory: number, bridgedConnection: string, networkDevice: string, localhost_name: string, ip4Address: string, 
  ip4Gateway: string, ip4Netmask: string, nameservers: NameserverT[], dnsSearch: string, sshKeys: SshKeyT[], 
  attachedStorage: AttachedStorageT[], user: string, password: string)
{
  const bodyData = {machineName, qcowImageId, osVariantId, vcpuCount, virtualMemory, bridgedConnection, networkDevice, hostId,
    nameservers, dnsSearch, sshKeys, user, password, localhost_name, ip4Address, ip4Gateway, ip4Netmask, 
    attachedStorage, config: 'template'};

  const response = await callDbTwig('dbos/createVmFromQcowImage', bodyData);
  return response;
}

export async function createUserSession(identification: string, password: string)
{
  const bodyData = { identification, password };
  const response = await callDbTwig('icam/createUserSession', bodyData);
  console.log(response);
  if (response.ok) await createSessionCookie(response.jsonData.sessionId, response.jsonData.accountType);
  return response;
}

export async function deleteVirtualMachine(virtualMachineId?: number, deleteBootDisk?: boolean)
{
  const bodyData = { virtualMachineId, deleteBootDisk: deleteBootDisk};
  const response = await callDbTwig('dbos/deleteVirtualMachine', bodyData);
  return response;
}

export async function getIsoSeedImages()
{
  const response = await callDbTwig('dbos/getIsoSeedImages');
  return response;
}

export async function getOsVariants()
{
  const response = await callDbTwig('dbos/getOsVariants');
  return response;
}

export async function getQcow2SeedImages()
{
  const response = await callDbTwig('dbos/getQcow2SeedImages');
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

export async function getVmHosts()
{
  const response = await callDbTwig('dbos/getVmHosts')
  return response;
}

export async function setPersistentFlag(virtualMachineId: number, persistent: string)
{
  const bodyData = { virtualMachineId, persistent };
  const response = await callDbTwig('dbos/setPersistent', bodyData);
  return response;
}

export async function startVirtualMachine(virtualMachineId: number)
{
  const bodyData = { virtualMachineId: virtualMachineId };
  const response = await callDbTwig('dbos/startVirtualMachine', bodyData);
  return response;
}

export async function stopVirtualMachine(virtualMachineId: number)
{
  const bodyData = { virtualMachineId: virtualMachineId };
  const response = await callDbTwig('dbos/stopVirtualMachine', bodyData);
  return response;
}

export async function terminateUserSession()
{
  const response = await callDbTwig('icam/terminateUserSession');
  if (response.ok) await deleteSessionCookie();
  return response;
}

/*
 * virtualMachines.c
 *
 *  Created on: Jul 7, 2025
 *      Author: gilly
 */


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/prctl.h>
#include <errno.h>
#include <malloc.h>
#include <limits.h>
#include <cjson/cJSON.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>

#include "vmHostMonitorDefs.h"
#include "oraDataLayer.h"
#include "errors.h"
#include "logger.h"
#include "vmHosts.h"

char *machineName, *vDiskFilename, *sparseAllocation, *vCdromFilename, *osVariant, *networkSource,
  *networkDevice, *bootDevice, commandLine[2048], *metaDataFilename, *userDataFilename, *netDataFilename, *persistent;

int vCpus = 0, vMemory = 0, vDiskSize = 0, rc = E_SUCCESS;

FILE *process = NULL;

extern int errno;

int stopVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH], *xmlDesc = NULL;
  int rc = E_SUCCESS;
  cJSON *item = NULL;
  virDomain *vm = NULL;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");
  machineName = item->valuestring;

  vm = virDomainLookupByName((virConnect *)vmHostConnection, machineName);
  if (!vm) return E_SUCCESS;

  xmlDesc = virDomainGetXMLDesc(vm, VIR_DOMAIN_XML_INACTIVE);
  if (xmlDesc)
  {
    rc = updateVmXMLDescription(machineName, xmlDesc);
    free(xmlDesc);
  }

  snprintf(text2Log, sizeof(text2Log)-1, "Stopping virtual machine: %s", machineName);
  logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  virDomainShutdownFlags(vm, VIR_DOMAIN_SHUTDOWN_DEFAULT);
  virDomainFree(vm);

  return rc;
}

int undefineVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  cJSON *item = NULL;
  virDomain *vm = NULL;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");
  machineName = item->valuestring;

  vm = virDomainLookupByName((virConnect *)vmHostConnection, machineName);
  if (!vm) return E_SUCCESS;

  virDomainUndefine(vm);
  virDomainFree(vm);

  snprintf(text2Log, sizeof(text2Log)-1, "Undefined virtual machine: %s", machineName);
  logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  return E_SUCCESS;
}

int createCloudInitCdrom(void)
{
  char text2Log[LOGMSG_LENGTH];
  cJSON *item = NULL;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "metaDataFilename");
  if (!item) return jsonError("metadataFilename");
  metaDataFilename = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "userDataFilename");
  if (!item) return jsonError("userDataFilename");
  userDataFilename = item->valuestring;

  netDataFilename = NULL;
  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "netDataFilename");
  if (item) netDataFilename = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vCdromFilename");
  if (!item) return jsonError("vCdromFilename");
  vCdromFilename = item->valuestring;

  if (!netDataFilename)
    snprintf(commandLine, sizeof(commandLine), "genisoimage -output %s -volid cidata -joliet -rock --graft-points user-data=%s meta-data=%s",
      vCdromFilename, userDataFilename, metaDataFilename);
  else
    snprintf(commandLine, sizeof(commandLine), "genisoimage -output %s -volid cidata -joliet -rock --graft-points user-data=%s meta-data=%s network-config=%s",
      vCdromFilename, userDataFilename, metaDataFilename, netDataFilename);

  logOutput(LOG_OUTPUT_VERBOSE, commandLine);

  process = popen(commandLine, "r");
  if (!process)
  {
    snprintf(text2Log, sizeof(text2Log), "Unable to create cloud-init CDROM: %s", strerror(errno));
    logOutput(LOG_OUTPUT_ERROR, text2Log);
    return E_CHILD_DIED;    // Should be using a better error code...
  }

  while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  pclose(process);

  return E_SUCCESS;
}

int startVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  cJSON *item = NULL;
  virDomain *virtualDomain = NULL;
  int virtualMachineId = 0, rc = E_SUCCESS, xmlDescriptionLength = 0;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");
  machineName = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "virtualMachineId");
  if (!item) return jsonError("virtualMachineId");
  virtualMachineId = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "xmlDescriptionLength");
  if (!item) return jsonError("xmlDescriptionLength");
  xmlDescriptionLength = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "persistent");
  if (!item) return jsonError("persistent");
  persistent = item->valuestring;

  rc = getVmXMLDescription(virtualMachineId, xmlDescriptionLength);
  if (rc) return rc;

  snprintf(text2Log, sizeof(text2Log)-1, "Starting virtual machine: %s", machineName);
  logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  if ('N' == *persistent)
  {
    virtualDomain = virDomainCreateXML((virConnect *)vmHostConnection, jsonResultStr, 0);
  }
  else
  {
    virtualDomain = virDomainDefineXML((virConnect *)vmHostConnection, jsonResultStr);
    if (virtualDomain) virDomainCreate(virtualDomain);
  }

  if (!virtualDomain)
  {
    vmHostErrorHandler();
    updateLifecycleState(machineName, "crashed", "startup failed");
    return E_LIBVIRT_ERROR;
  }

  virDomainFree(virtualDomain);

  return E_SUCCESS;
}

int createVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  char vDiskOptions[VDISK_OPTIONS_LENGTH];
  cJSON *item = NULL, *array = NULL, *entry = NULL;
  virDomain *virtualDomain = NULL;
  int rc = E_SUCCESS, x = 0;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");
  machineName = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vDiskFilename");
  if (!item) return jsonError("vDiskFilename");
  vDiskFilename = item->valuestring;

  vDiskSize = 0;
  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "diskSize");
  if (item) vDiskSize = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "sparseAllocation");
  if (item) sparseAllocation = item->valuestring;

  bzero(vDiskOptions, sizeof(vDiskOptions));
  if (vDiskSize) snprintf(vDiskOptions, sizeof(vDiskOptions)-1, ",size=%d,sparse=%s", vDiskSize, 'Y' == *sparseAllocation ? "true" : "false");

  vCdromFilename = NULL;
  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vCdromFilename");
  if (item) vCdromFilename = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vCpus");
  if (!item) return jsonError("vCpus");
  vCpus = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vMemory");
  if (!item) return jsonError("vMemory");
  vMemory = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "osVariant");
  if (!item) return jsonError("osVariant");
  osVariant = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "networkSource");
  if (!item) return jsonError("networkSource");
  networkSource = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "networkDevice");
  if (!item) return jsonError("networkDevice");
  networkDevice = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "bootDevice");
  if (!item) return jsonError("bootDevice");
  bootDevice = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "persistent");
  if (!item) return jsonError("persistent");
  persistent = item->valuestring;

  bzero(commandLine, sizeof(commandLine));

  if (!vCdromFilename)
    snprintf(commandLine, sizeof(commandLine)-1, "%s --name %s --memory %d --vcpus %d --boot %s --disk %s --os-variant %s --virt-type kvm --network %s=%s,model=virtio --import --noautoconsole --connect qemu:///system ",
      VIRT_INSTALL, machineName, vMemory, vCpus, bootDevice, vDiskFilename, osVariant, networkSource, networkDevice);
  else
    snprintf(commandLine, sizeof(commandLine)-1, "%s --name %s --memory %d --vcpus %d --boot %s --disk %s%s --disk %s,device=cdrom --os-variant %s --virt-type kvm --network %s=%s,model=virtio --import --noautoconsole --connect qemu:///system ",
      VIRT_INSTALL, machineName, vMemory, vCpus, bootDevice, vDiskFilename, vDiskOptions, vCdromFilename, osVariant, networkSource, networkDevice);

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "attachedStorage");
  if (!item) return jsonError("attachedStorage");
  array = item;

  for (x = 0; x < cJSON_GetArraySize(array); x++)
  {
    entry = cJSON_GetArrayItem(array, x);
    if (!entry) return jsonError("Array item missing...");

    item = cJSON_GetObjectItemCaseSensitive(entry, "diskSize");
    if (!item) return jsonError("diskSize");
    vDiskSize = item->valueint;

    item = cJSON_GetObjectItemCaseSensitive(entry, "sparseAllocation");
    if (!item) return jsonError("sparseAllocation");
    sparseAllocation = item->valuestring;

    item = cJSON_GetObjectItemCaseSensitive(entry, "vDiskFilename");
    if (!item) return jsonError("vDiskFilename");

    bzero(vDiskOptions, sizeof(vDiskOptions));
    snprintf(vDiskOptions, sizeof(vDiskOptions)-1, ",size=%d,sparse=%s", vDiskSize, 'Y' == *sparseAllocation ? "true" : "false");
    snprintf(commandLine+strlen(commandLine), sizeof(commandLine) - strlen(commandLine), " --disk %s%s", item->valuestring, vDiskOptions);
  }

  snprintf(commandLine+strlen(commandLine), sizeof(commandLine) - strlen(commandLine), " 2>&1");

  logOutput(LOG_OUTPUT_VERBOSE, commandLine);

  updateLifecycleState(machineName, "starting", "startup requested");

  process = popen(commandLine, "r");
  if (!process)
  {
    snprintf(text2Log, sizeof(text2Log), "Unable to start VM: %s", strerror(errno));
    logOutput(LOG_OUTPUT_ERROR, text2Log);
    updateLifecycleState(machineName, "crashed", "startup failed");
    return E_PLUGIN_ERROR;
  }

  while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  pclose(process);

  if (!virtualMachineIsRunning(machineName))
  {
    updateLifecycleState(machineName, "crashed", "install failed");
    return E_PLUGIN_ERROR;
  }

  if (vCdromFilename)
  {
    snprintf(commandLine, sizeof(commandLine), "%s detach-disk %s sda --config", VIRT_SHELL, machineName);
    logOutput(LOG_OUTPUT_VERBOSE, commandLine);

    process = popen(commandLine, "r");
    if (!process)
    {
      snprintf(text2Log, sizeof(text2Log), "Unable to remove cdrom drive: %s", strerror(errno));
      logOutput(LOG_OUTPUT_ERROR, text2Log);
    }

    while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

    pclose(process);
  }

  if ('N' == *persistent)
  {
    virtualDomain = (virDomain *) getVirtualDomain(machineName);
    if (!virtualDomain) return E_RETURN_TYPE;
    rc = virDomainUndefineFlags(virtualDomain, 0);
    if (rc) vmHostErrorHandler();
    virDomainFree(virtualDomain);
  }

  return E_SUCCESS;
}


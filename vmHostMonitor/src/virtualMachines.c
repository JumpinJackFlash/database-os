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

char *machineName, *vDiskFilename, *sparseDiskAllocation, *vCdromFilename, *osVariant, *networkSource,
  *networkDevice, *bootDevice, commandLine[2048], *metaDataFilename, *userDataFilename, *netDataFilename, *persistent;

int vCpus = 0, vMemory = 0, vDiskSize = 0, rc = E_SUCCESS;

FILE *process = NULL;

extern int errno;

int stopVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  cJSON *item = NULL;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");

  snprintf(commandLine, sizeof(commandLine), "%s -c qemu:///system shutdown %s", VIRT_SHELL, item->valuestring);
  logOutput(LOG_OUTPUT_VERBOSE, commandLine);

  process = popen(commandLine, "r");
  if (!process)
  {
    snprintf(text2Log, sizeof(text2Log), "Unable to shutdown VM: %s", strerror(errno));
    logOutput(LOG_OUTPUT_ERROR, text2Log);
    return E_CHILD_DIED;
  }

  while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  pclose(process);

  return E_SUCCESS;
}

int undefineVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  cJSON *item = NULL;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");

  snprintf(commandLine, sizeof(commandLine), "%s -c qemu:///system undefine %s", VIRT_SHELL, item->valuestring);
  logOutput(LOG_OUTPUT_VERBOSE, commandLine);

  process = popen(commandLine, "r");
  if (!process)
  {
    snprintf(text2Log, sizeof(text2Log), "Unable to undefine VM: %s", strerror(errno));
    logOutput(LOG_OUTPUT_ERROR, text2Log);
    return E_CHILD_DIED;
  }

  while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  pclose(process);

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

  rc = getVmXMLDescription(virtualMachineId, xmlDescriptionLength);
  if (rc) return rc;

  snprintf(text2Log, sizeof(text2Log)-1, "Starting virtual machine: %s", machineName);
  logOutput(LOG_OUTPUT_VERBOSE, text2Log);
  logOutput(LOG_OUTPUT_VERBOSE, jsonResultStr);

  virtualDomain = virDomainCreateXML((virConnect *)vmHostConnection, jsonResultStr, 0);
  if (!virtualDomain)
  {
    vmHostErrorHandler();
    return E_LIBVIRT_ERROR;
  }

  virDomainFree(virtualDomain);

  return E_SUCCESS;
}

int createVirtualMachine(void)
{
  char text2Log[LOGMSG_LENGTH];
  char vDiskOptions[VDISK_OPTIONS_LENGTH];
  cJSON *item = NULL;
  virDomain *virtualDomain = NULL;
  int rc = E_SUCCESS;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "machineName");
  if (!item) return jsonError("machineName");
  machineName = item->valuestring;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vDiskFilename");
  if (!item) return jsonError("vDiskFilename");
  vDiskFilename = item->valuestring;

  vDiskSize = 0;
  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "vDiskSize");
  if (item) vDiskSize = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(messagePayload, "sparseDiskAllocation");
  if (item) sparseDiskAllocation = item->valuestring;

  bzero(vDiskOptions, sizeof(vDiskOptions));
  if (vDiskSize) snprintf(vDiskOptions, sizeof(vDiskOptions)-1, ",size=%d,sparse=%s", vDiskSize, 'Y' == *sparseDiskAllocation ? "true" : "false");

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

  if (!vCdromFilename)
    snprintf(commandLine, sizeof(commandLine), "%s --name %s --memory %d --vcpus %d --boot %s --disk %s --os-variant %s --virt-type kvm --network %s=%s,model=virtio --import --noautoconsole --connect qemu:///system 2>&1",
      VIRT_INSTALL, machineName, vMemory, vCpus, bootDevice, vDiskFilename, osVariant, networkSource, networkDevice);
  else
    snprintf(commandLine, sizeof(commandLine), "%s --name %s --memory %d --vcpus %d --boot %s --disk %s%s --disk %s,device=cdrom --os-variant %s --virt-type kvm --network %s=%s,model=virtio --import --noautoconsole --connect qemu:///system 2>&1",
      VIRT_INSTALL, machineName, vMemory, vCpus, bootDevice, vDiskFilename, vDiskOptions, vCdromFilename, osVariant, networkSource, networkDevice);

  logOutput(LOG_OUTPUT_VERBOSE, commandLine);

  updateLifecycleState(machineName, "starting", "startup requested", NULL);

  process = popen(commandLine, "r");
  if (!process)
  {
    snprintf(text2Log, sizeof(text2Log), "Unable to start VM: %s", strerror(errno));
    logOutput(LOG_OUTPUT_ERROR, text2Log);
    updateLifecycleState(machineName, "crashed", "startup failed", NULL);
    return E_PLUGIN_ERROR;
  }

  while (fgets(text2Log, sizeof(text2Log), process)) logOutput(LOG_OUTPUT_VERBOSE, text2Log);

  pclose(process);

  if (!virtualMachineIsRunning(machineName))
  {
    updateLifecycleState(machineName, "crashed", "install failed", NULL);
    return E_SUCCESS;
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

#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <sys/signalfd.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
#include <limits.h>
#include <sys/utsname.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>

#include <cjson/cJSON.h>

#include "vmHostMonitorDefs.h"
#include "oraDataLayer.h"
#include "errors.h"
#include "logger.h"

static virConnectPtr vmConnection = NULL;
static virErrorPtr vmError = NULL;

static int selfSignalFD = 0;
static int keepRunning = TRUE;

int vmHostErrorHandler(void)
{
  logOutput(LOG_OUTPUT_ERROR, (char *) virGetLastErrorMessage());
  return E_LIBVIRT_ERROR;
}

static char *decodeEvent(int event)
{
  switch (event)
  {
    case VIR_DOMAIN_EVENT_DEFINED:
      return "defined";

    case VIR_DOMAIN_EVENT_UNDEFINED:
      return "undefined";

    case VIR_DOMAIN_EVENT_STARTED:
      return "started";

    case VIR_DOMAIN_EVENT_SUSPENDED:
      return "suspended";

    case VIR_DOMAIN_EVENT_RESUMED:
      return "resumed";

    case VIR_DOMAIN_EVENT_STOPPED:
      return "stopped";

    case VIR_DOMAIN_EVENT_SHUTDOWN:
      return "shutdown";

    case VIR_DOMAIN_EVENT_PMSUSPENDED:
      return "pmsuspended";

    case VIR_DOMAIN_EVENT_CRASHED:
      return "crashed";

    default:
      return "unknown";
  }
}

static char *decodeState(int state)
{
  switch (state)
  {
    case VIR_DOMAIN_NOSTATE:
      return "unknown";

    case VIR_DOMAIN_RUNNING:
      return "running";

    case VIR_DOMAIN_BLOCKED:
      return "blocked";

    case VIR_DOMAIN_PAUSED:
      return "paused";

    case VIR_DOMAIN_SHUTDOWN:
      return "stopping";

    case VIR_DOMAIN_SHUTOFF:
      return "stopped";

    case VIR_DOMAIN_CRASHED:
      return "crashed";

    case VIR_DOMAIN_PMSUSPENDED:
      return "pmsuspended";

    default:
      return "unknown";
  }
}

void *getVirtualDomain(char *machineName)
{
int rc = E_SUCCESS, x = 0, state = 0, reason = 0;
virDomain **domains = NULL, *domain = NULL;
unsigned int dCount = 0;

  rc = virConnectListAllDomains(vmConnection, &domains, 0);
  if (-1 == rc)
  {
    vmHostErrorHandler();
    return NULL;
  }

  dCount = rc;
  for (x = 0; x < dCount; x++)
  {
    domain = domains[x];

    rc = virDomainGetState(domain, &state, &reason, 0);
    if (-1 == rc)
    {
      virDomainFree(domain);
      free(domains);
      vmHostErrorHandler();
      return NULL;
    }
    if (!strcmp(machineName, virDomainGetName(domain))) return domain;
    virDomainFree(domain);
  }
  free(domains);

  return NULL;
}

int virtualMachineIsRunning(char *machineName)
{
int rc = E_SUCCESS, x = 0, state = 0, reason = 0, running = FALSE;
virDomain **domains = NULL, *domain = NULL;
unsigned int dCount = 0;

  rc = virConnectListAllDomains(vmConnection, &domains, 0);
  if (-1 == rc) return vmHostErrorHandler();

  dCount = rc;
  for (x = 0; x < dCount; x++)
  {
    domain = domains[x];

    rc = virDomainGetState(domain, &state, &reason, 0);
    if (-1 == rc)
    {
      virDomainFree(domain);
      free(domains);
      vmHostErrorHandler();
      return FALSE;
    }
    if (!strcmp(machineName, virDomainGetName(domain)) && VIR_DOMAIN_RUNNING == state) running = TRUE;
    virDomainFree(domain);
    if (running) break;
  }
  free(domains);

  return running;
}

// It would be best to properly clean up if an error is thrown but, since we're going to crap out anyways we won't bother for now...

static int getVirtualMachineList(void)
{
int rc = E_SUCCESS, x = 0, state = 0, reason = 0, isPersistent = 0, nInterfaces = 0, y = 0, z = 0;
virDomain **domains = NULL, *domain = NULL;
virDomainInterface **interfaces = NULL, *interface = NULL;
virDomainIPAddress *address = NULL;
char uuid[VIR_UUID_STRING_BUFLEN];
unsigned int dCount = 0;
cJSON *jsonParms = NULL, *item = NULL, *cjInterfaces = NULL, *cjInterface = NULL, *entryPoint = NULL;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  entryPoint = cJSON_AddStringToObject(jsonParms, "entryPoint", "validateVmState");
  if (!entryPoint) return E_JSON_ERROR;

  rc = virConnectListAllDomains(vmConnection, &domains, 0);
  if (-1 == rc) return vmHostErrorHandler();

  dCount = rc;
  for (x = 0; x < dCount; x++)
  {
    domain = domains[x];

    item = cJSON_GetObjectItemCaseSensitive(jsonParms, "machineName");
    if (item)
      cJSON_SetValuestring(item, virDomainGetName(domain));
    else
      item = cJSON_AddStringToObject(jsonParms, "machineName", virDomainGetName(domain));

    rc = virDomainGetState(domain, &state, &reason, 0);

    item = cJSON_GetObjectItemCaseSensitive(jsonParms, "lifecycleState");
    if (item)
      cJSON_SetValuestring(item, decodeState(state));
    else
      item = cJSON_AddStringToObject(jsonParms, "lifecycleState", decodeState(state));

    rc = virDomainGetUUIDString(domain, uuid);

    item = cJSON_GetObjectItemCaseSensitive(jsonParms, "uuid");
    if (item)
      cJSON_SetValuestring(item, uuid);
    else
      item = cJSON_AddStringToObject(jsonParms, "uuid", uuid);

    isPersistent = virDomainIsPersistent(domain);

    item = cJSON_GetObjectItemCaseSensitive(jsonParms, "persistent");
    if (item)
      cJSON_SetValuestring(item, isPersistent ? "Y" : "N");
    else
      item = cJSON_AddStringToObject(jsonParms, "persistent", isPersistent ? "Y" : "N");

    cjInterfaces = cJSON_GetObjectItemCaseSensitive(jsonParms, "interfaces");
    if (cjInterfaces)
    {
      cJSON_DeleteItemFromObjectCaseSensitive(jsonParms, "interfaces");
      cjInterfaces = cJSON_AddArrayToObject(jsonParms, "interfaces");
    }
    else
      cjInterfaces = cJSON_AddArrayToObject(jsonParms, "interfaces");

    if (!cjInterfaces) return E_JSON_ERROR;

    if (VIR_DOMAIN_RUNNING == state)
    {
      nInterfaces = virDomainInterfaceAddresses(domain, &interfaces, VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_LEASE, 0);
      if (nInterfaces <= 0) nInterfaces = virDomainInterfaceAddresses(domain, &interfaces, VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_AGENT, 0);
      if (nInterfaces <= 0) nInterfaces = virDomainInterfaceAddresses(domain, &interfaces, VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_ARP, 0);

      if (interfaces)
      {
        for (y = 0; y < nInterfaces; y++)
        {
          interface = interfaces[y];
          if (strcmp(interface->name, "lo"))
          {
            cjInterface = cJSON_CreateObject();
            if (!cjInterface) return E_JSON_ERROR;

            item = cJSON_AddStringToObject(cjInterface, "device", interface->name);

            address = interface->addrs;
            for (z = 0; z < interface->naddrs; z++)
            {
              if (VIR_IP_ADDR_TYPE_IPV4 == address->type) item = cJSON_AddStringToObject(cjInterface, "ipAddress", address->addr);
              address++;
            }

            rc = cJSON_AddItemToArray(cjInterfaces, cjInterface);
          }
        }

        for (y = 0; y < nInterfaces; y++)
        {
          interface = interfaces[y];
          virDomainInterfaceFree(interface);
        }
      }
    }

    rc = validateVmState((void *)jsonParms);

    cJSON_SetValuestring(entryPoint, "updateVmState");
    rc = updateVmState((void *)jsonParms);

    cJSON_SetValuestring(entryPoint, "validateVmState");                // Reset for next iteration of the loop...

    virDomainFree(domains[x]);
  }
  free(domains);

  if (jsonParms) cJSON_Delete(jsonParms);
  return E_SUCCESS;
}

static void selfSignalCallback(int watch, int fd, int events, void * opaque)
{
  logOutput(LOG_OUTPUT_ALWAYS, "signal callback");
  keepRunning = FALSE;
}

static int setupSelfSignal(void)
{
sigset_t mask;
int rc = E_SUCCESS;
struct sigaction sigAction;

  sigemptyset(&mask);
  sigaddset(&mask, SIGTERM);
  sigaddset(&mask, SIGQUIT);
  sigaddset(&mask, SIGABRT);

  sigAction.sa_handler = SIG_IGN;
  rc = sigaction(SIGTERM, &sigAction, NULL);

  selfSignalFD = signalfd(-1, &mask, 0);
  if (-1 == selfSignalFD) return E_OSERR;

  rc = virEventAddHandle(selfSignalFD, VIR_EVENT_HANDLE_READABLE|VIR_EVENT_HANDLE_WRITABLE|VIR_EVENT_HANDLE_ERROR|VIR_EVENT_HANDLE_HANGUP, selfSignalCallback, NULL, NULL);

  return rc;
}

int connectToVmHost(void)
{
int rc = E_SUCCESS;
unsigned long hypervisorVersion = 0l, libvirtVersion = 0l;
char *vmHostSysinfo = NULL, *vmHostCapabilities = NULL;
struct utsname utsnameBuffer;

  bzero(&utsnameBuffer, sizeof(utsnameBuffer));
  rc = uname(&utsnameBuffer);

  vmConnection = virConnectOpen("qemu:///system");

  if (!vmConnection)
  {
    vmError = virGetLastError();
    logOutput(LOG_OUTPUT_ERROR, vmError->message);
  }

  vmHostSysinfo = virConnectGetSysinfo(vmConnection, 0);
  vmHostCapabilities = virConnectGetCapabilities(vmConnection);

  rc = virConnectGetVersion(vmConnection, &hypervisorVersion);
  rc = virConnectGetLibVersion(vmConnection, &libvirtVersion);

  setupSelfSignal();

  rc = registerVmHost(vmHostSysinfo, vmHostCapabilities, hypervisorVersion, libvirtVersion,
    utsnameBuffer.release, utsnameBuffer.machine);

  free(vmHostSysinfo);
  free(vmHostCapabilities);

  rc = getVirtualMachineList();

  return rc;
}

static int domainEventHandler(virConnect *conn, virDomain *domain, int event, int detail, void *opaque)
{
const char *domainName = NULL;

  domainName = virDomainGetName(domain);
  logOutput(LOG_OUTPUT_ALWAYS, (char *) domainName);
  logOutput(LOG_OUTPUT_ALWAYS, (char *) decodeEvent(event));

  switch (event)
  {
    case VIR_DOMAIN_EVENT_STARTED:
      updateLifecycleState((char *) domainName, "starting");
      break;

    case VIR_DOMAIN_EVENT_SHUTDOWN:
      updateLifecycleState((char *) domainName, "stopping");
      break;

    case VIR_DOMAIN_EVENT_STOPPED:
      updateLifecycleState((char *) domainName, "stopped");
      break;

    case VIR_DOMAIN_EVENT_UNDEFINED:
      updatePersistence((char *) domainName, "N");
      break;

    case VIR_DOMAIN_EVENT_DEFINED:
      updatePersistence((char *) domainName, "Y");
      break;
  }

  return E_SUCCESS;
}

int setupEventLoop(void)
{
int rc = E_SUCCESS;

  rc = virEventRegisterDefaultImpl();

  return rc;
}

int monitorDomainEvents(void)
{
int rc = E_SUCCESS;

  rc = virConnectDomainEventRegisterAny(vmConnection, NULL, VIR_DOMAIN_EVENT_ID_LIFECYCLE, VIR_DOMAIN_EVENT_CALLBACK(domainEventHandler), NULL, NULL);

  while (keepRunning) virEventRunDefaultImpl();

  return rc;
}

void disconnectFromVmHost(void)
{
  setVmHostOffline();
  virConnectClose(vmConnection);
}

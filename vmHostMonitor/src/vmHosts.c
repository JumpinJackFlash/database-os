#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <sys/utsname.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>

#include <commonDefs.h>

#include "oraDataLayer.h"

static virConnectPtr vmConnection = NULL;
static virErrorPtr vmError = NULL;

static int vmHostErrorHandler(void)
{
  logOutput(LOG_OUTPUT_ERROR, (char *) virGetLastErrorMessage());
  return E_LIBVIRT_ERROR;
}

static int getVirtualMachineList(void)
{
int rc = E_SUCCESS, x = 0, state = 0, reason = 0, isPersistent = 0, nInterfaces = 0, y = 0, z = 0;
virDomain **domains = NULL, *domain = NULL;
virDomainInterface **interfaces = NULL, *interface = NULL;
virDomainIPAddress *address = NULL;
virDomainInfo domainInfo;
const char *domainName = NULL;
char uuid[VIR_UUID_STRING_BUFLEN];
unsigned int dCount = 0;

  rc = virConnectListAllDomains(vmConnection, &domains, 0);
  if (-1 == rc) return vmHostErrorHandler();

  dCount = rc;
  for (x = 0; x < dCount; x++)
  {
    domain = domains[x];
    virDomainGetInfo(domain, &domainInfo);
    domainName = virDomainGetName(domain);
    rc = virDomainGetState(domain, &state, &reason, 0);
    rc = virDomainGetUUIDString(domain, uuid);
    isPersistent = virDomainIsPersistent(domain);

    if (VIR_DOMAIN_RUNNING == state)
    {
      nInterfaces = virDomainInterfaceAddresses(domain, &interfaces, 1, 0);

      if (interfaces)
      {
        for (y = 0; y < nInterfaces; y++)
        {
          interface = interfaces[y];
          if (strcmp(interface->name, "lo"))
          {
            address = interface->addrs;
            for (z = 0; z < interface->naddrs; z++)
            {
              if (VIR_IP_ADDR_TYPE_IPV4 == address->type) logOutput(LOG_OUTPUT_ALWAYS, address->addr);
              address++;
            }
          }
        }
        for (y = 0; y < nInterfaces; y++)
        {
          interface = interfaces[y];
          virDomainInterfaceFree(interface);
        }
      }
    }

    virDomainFree(domains[x]);
  }
  free(domains);

  return E_SUCCESS;
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

  rc = registerVmHost(vmHostSysinfo, vmHostCapabilities, hypervisorVersion, libvirtVersion,
    utsnameBuffer.release, utsnameBuffer.machine);

  free(vmHostSysinfo);
  free(vmHostCapabilities);

  getVirtualMachineList();

  return rc;
}

void disconnectFromVmHost(void)
{
int rc = E_SUCCESS;

  rc = setVmHostOffline();

  virConnectClose(vmConnection);
}

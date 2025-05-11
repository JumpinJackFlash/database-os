#include <stdio.h>
#include <malloc.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>

#include <commonDefs.h>

static virConnectPtr vmConnection = NULL;
static virErrorPtr vmError = NULL;

int connectToVmHost(void)
{
int rc = E_SUCCESS;
char *vmHostSysinfo = NULL;

  vmConnection = virConnectOpen("qemu:///system");

  if (!vmConnection)
  {
    vmError = virGetLastError();
    logOutput(LOG_OUTPUT_ERROR, vmError->message);
  }

  vmHostSysinfo = virConnectGetSysinfo(vmConnection, 0);
  logOutput(LOG_OUTPUT_ALWAYS, vmHostSysinfo);
  free(vmHostSysinfo);
  return rc;
}

void disconnectFromVmHost(void)
{
  virConnectClose(vmConnection);
}

/*
 * dbQueueMonitor.c
 *
 *  Created on: Jun 29, 2025
 *      Author: gilly
 */

#include <stdlib.h>
#include <pthread.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

#include <cjson/cJSON.h>

#include "vmHostMonitorDefs.h"
#include "errors.h"
#include "oraDataLayer.h"
#include "logger.h"
#include "virtualMachines.h"

static pthread_t queueThreadID;
static int queueThreadStatus = E_SUCCESS;

static int monitorQueue(void)
{
int rc = E_SUCCESS;
cJSON *item = NULL;

wait_for_another:

  messagePayload = NULL;
  rc = getMsgForVmHostMonitor();
  if (rc) return rc;

  switch (messageType)
  {
    case MSGT_STOP_QUEUE_THREAD:
      if (messagePayload) cJSON_Delete(messagePayload);
      return rc;

    case MSGT_START_VM:
      rc = startVirtualMachine();
      break;

    case MSGT_STOP_VM:
      rc = stopVirtualMachine();
      break;

    case MSGT_UNDEFINE_VM:
      rc = undefineVirtualMachine();
      break;

    case MSGT_CREATE_CLOUD_INIT_CDROM:
      rc = createCloudInitCdrom();
      if (responsePayload) cJSON_Delete(responsePayload);
      responsePayload = cJSON_CreateObject();
      if (!responsePayload) return E_MALLOC;
      item = cJSON_AddStringToObject(responsePayload, "status", rc ? "failure" : "success");
      if (!item) return E_MALLOC;
      rc = sendMessageToClient();
      break;
  }

  if (messagePayload) cJSON_Delete(messagePayload);

  goto wait_for_another;

  return E_SUCCESS;
}

static void *queueThread(void *dumbArg)
{
int rc = E_SUCCESS, cancelType = 0;

  pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, &cancelType);

  rc = monitorQueue();

  if (rc && E_STOP_QUEUE_THREAD != rc) logOutput(LOG_OUTPUT_ERROR, getErrorText(rc));

  queueThreadStatus = rc;

  pthread_exit(&rc);
  return E_SUCCESS;
}

int startQueueThread(void)
{
int rc = E_SUCCESS;

  rc = pthread_create(&queueThreadID, NULL, queueThread, (void *) NULL);
  if (rc)
  {
    logOutput(LOG_OUTPUT_ERROR, "Unable to start queue monitor thread.");
    logOutput(LOG_OUTPUT_ERROR, strerror(errno));
    return E_FATAL_SERVER_ERROR;
  }

  return rc;
}

int stopQueueThread(void)
{
int rc = E_SUCCESS;

  if (!queueThreadID) return rc;

  if (!queueThreadStatus) rc = breakDqSession();
  if (rc) return rc;

  pthread_join(queueThreadID, NULL);

  return E_SUCCESS;
}


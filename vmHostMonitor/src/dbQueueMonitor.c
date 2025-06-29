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

#include "commonDefs.h"
#include "oraDataLayer.h"
#include "vmHostMonitorDefs.h"

static pthread_t queueThreadID;
static int queueThreadStatus = E_SUCCESS;

static int monitorQueue(void)
{
int rc = E_SUCCESS;

wait_for_another:

  rc = getMsgForVmHostMonitor();
  if (rc) return rc;

  switch (messageType)
  {
    case MSGT_STOP_QUEUE_THREAD:
      return rc;

  }

  goto wait_for_another;

  return E_SUCCESS;
}

static void *queueThread(void *dumbArg)
{
int rc = E_SUCCESS;

  setThreadCancelType();

  rc = monitorQueue();

  if (rc && E_STOP_QUEUE_THREAD != rc) logOutput(LOG_OUTPUT_ERROR, getDbPluginErrorText(rc));

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


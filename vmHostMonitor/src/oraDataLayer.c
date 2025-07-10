/*
 * oraDataLayer.c
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

#include <oci.h>

#include <cjson/cJSON.h>

#include <commonDefs.h>
#include <oraCommon.h>

#include "vmHostMonitor.h"

static OCI_CONNECTION   dbConn;                                                 // Main thread connection.
static OCI_CONNECTION   qConn;

static OCI_SESSION qSess;
static OCI_SESSION dbSess;

static char jsonParametersStr[16384];
static char jsonResultStr[8192];
static char queueParms[8192];
static char queueData[8192];

static char *callApiTxt = "begin :jsonResult := vm_manager_runtime.call_api(:hostName, :jsonParameters); end;";

static OCIStmt *dbConnStmt = NULL;
static OCIStmt *qConnStmt = NULL;

static OCIBind *jsonParmsBV = NULL;
static OCIBind *jsonResultBV = NULL;

static OCIBind *queueParmsBV = NULL;
static OCIBind *queueDataBV = NULL;

static OCIBind *hostNameBV = NULL;

static sb4 oraErrorCode = OCI_SUCCESS;

static pthread_mutex_t dbConnMtx;

char clientHandle[CLIENT_HANDLE_LENGTH];
cJSON *messagePayload = NULL;
cJSON *responsePayload = NULL;
int messageType;

static int errorHandler(int rc, OCIError *error)
{
int oraReturnCode = E_SUCCESS;

  if (error)
  {
    oraReturnCode = oraErrorHandler(rc, error);
    oraErrorCode = getOraErrorCode();
    if (oraReturnCode && OCI_USER_REQUESTED_CANCEL != oraErrorCode && OCI_ILLEGAL_PARM_VALUE != oraErrorCode &&
        OCI_QUEUE_TIMEOUT != oraErrorCode && OCI_ARRAY_DQ_FAIL != oraErrorCode)
      logOutput(LOG_OUTPUT_ERROR, getOraErrorText());
    return oraReturnCode;
  }

  return rc;
}

static int reEstablishQueueConnection(void)
{
int rc = E_SUCCESS;

  rc = getSessionFromSPool(&dbConn, &qSess);
  if (rc) return errorHandler(rc, NULL);

  logOutput(LOG_OUTPUT_WARN, "Queue connection re-established.");

  return rc;
}

int connectToDatabase(void)
{
int rc = E_SUCCESS;
cJSON *jsonParms = NULL, *item = NULL;

  logOutput(LOG_OUTPUT_ALWAYS, "Connecting to the database...");

  bzero(&dbConn, sizeof(dbConn));
  osStrcpy(dbConn.database, databaseName, sizeof(dbConn.database));
  rc = connectToOracleAction(&dbConn);
  if (rc) return errorHandler(rc, NULL);

  bzero(&qConn, sizeof(qConn));
  osStrcpy(qConn.database, databaseName, sizeof(qConn.database));
  rc = connectToOracleAction(&qConn);
  if (rc) return errorHandler(rc, NULL);

  bzero(&qSess, sizeof(qSess));
  osStrcpy(qSess.username, runtimeUser, sizeof(qSess.username));
  osStrcpy(qSess.password, runtimePassword, sizeof(qSess.password));
  rc = createOracleSession(&qConn, &qSess);
  if (rc) return errorHandler(rc, NULL);

  bzero(&dbSess, sizeof(OCI_SESSION));
  osStrcpy(dbSess.username, runtimeUser, sizeof(dbSess.username));
  osStrcpy(dbSess.password, runtimePassword, sizeof(dbSess.password));
  rc = createOracleSession(&dbConn, &dbSess);
  if (rc) return errorHandler(rc, NULL);

  rc = OCIHandleAlloc(dbConn.oraEnv, (void *)&dbConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);
  rc = OCIHandleAlloc(qConn.oraEnv, (void *)&qConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);

  rc = OCIStmtPrepare2(dbSess.oraSvcCtx, &dbConnStmt, dbSess.oraError, (const OraText *)callApiTxt,
    (ub4) strlen(callApiTxt), (const OraText *) NULL, (ub4) 0, OCI_NTV_SYNTAX, OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIBindByName(dbConnStmt, &hostNameBV, dbSess.oraError, (const OraText *)":hostName", -1,
    hostName, (ub4) sizeof(hostName)-1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIBindByName(dbConnStmt, &jsonResultBV, dbSess.oraError, (const OraText *)":jsonResult", -1,
    jsonResultStr, (ub4) sizeof(jsonResultStr)-1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIStmtPrepare2(qSess.oraSvcCtx, &qConnStmt, qSess.oraError, (const OraText *)callApiTxt,
    (ub4) strlen(callApiTxt), (const OraText *) NULL, (ub4) 0, OCI_NTV_SYNTAX, OCI_DEFAULT);
  if (rc) return errorHandler(rc, qSess.oraError);

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;
  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "getMessageForHostMonitor");
  if (!item) return E_JSON_ERROR;

  rc = cJSON_PrintPreallocated(jsonParms, queueParms, sizeof(queueParms), 0);
  if (!rc) return E_MALLOC;

  if (jsonParms) cJSON_Delete(jsonParms);

  rc = OCIBindByName(qConnStmt, &hostNameBV, dbSess.oraError, (const OraText *)":hostName", -1,
    hostName, (ub4) sizeof(hostName)-1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIBindByName(qConnStmt, &queueParmsBV, qSess.oraError, (const OraText *)":jsonParameters", -1,
    queueParms, (ub4) strlen(queueParms)+1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIBindByName(qConnStmt, &queueDataBV, qSess.oraError, (const OraText *)":jsonResult", -1,
    queueData, (ub4) sizeof(queueData)-1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  pthread_mutex_init(&dbConnMtx, NULL);

  return rc;
}

void closeStatementHandles(void)
{
  logOutput(LOG_OUTPUT_INFO, "Closing SQL statement cursors.");

  OCIHandleFree(&dbConnStmt, OCI_HTYPE_STMT);
  OCIHandleFree(&qConnStmt, OCI_HTYPE_STMT);
}

int disconnectFromDatabase(void)
{
  logOutput(LOG_OUTPUT_INFO, "Disconnecting from the Oracle database.");

  dropOracleSession(&qSess);
  dropOracleSession(&dbSess);
  disconnectFromOracleAction(&dbConn);
  disconnectFromOracleAction(&qConn);
  pthread_mutex_destroy(&dbConnMtx);

  return E_SUCCESS;
}

int registerVmHost(char *sysInfo, char *hostCapabilities, unsigned long hypervisorVersion, unsigned long libvirtVersion,
  char *osRelease, char *machineType)
{
cJSON *jsonParms = NULL, *item = NULL;
int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "registerVmHost");
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "sysInfo", sysInfo);
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "hostCapabilities", hostCapabilities);
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddNumberToObject(jsonParms, "hypervisorVersion", (double) hypervisorVersion);
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddNumberToObject(jsonParms, "libvirtVersion", (double) libvirtVersion);
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "osRelease", osRelease);
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "machineType", machineType);
  if (!item) return E_JSON_ERROR;

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }
  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);
  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}

int updateLifecycleState(char *machineName, char *lifecycleState)
{
cJSON *jsonParms = NULL, *jsonObject = NULL, *item = NULL;
int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  jsonObject = cJSON_CreateObject();
  if (!jsonObject) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "updateLifecycleState");
  if (!item) return jsonError("entryPoint");

  item = cJSON_AddStringToObject(jsonParms, "clientHandle", clientHandle);
  if (!item) return jsonError("clientHandle");

  item = cJSON_AddStringToObject(jsonObject, "machineName", machineName);
  if (!item) return jsonError("machineName");

  item = cJSON_AddStringToObject(jsonObject, "lifecycleState", lifecycleState);
  if (!item) return jsonError("lifecycleState");

  rc = cJSON_AddItemToObject(jsonParms, "messagePayload", jsonObject);
  if (!rc) return jsonError("messagePayload");

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  pthread_mutex_lock(&dbConnMtx);

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  pthread_mutex_unlock(&dbConnMtx);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}

int sendMessageToClient(void)
{
cJSON *jsonParms = NULL, *item = NULL;
int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "sendMessageToClient");
  if (!item) return jsonError("entryPoint");

  item = cJSON_AddStringToObject(jsonParms, "clientHandle", clientHandle);
  if (!item) return jsonError("clientHandle");

  rc = cJSON_AddItemToObject(jsonParms, "messagePayload", responsePayload);
  if (!rc) return jsonError("messagePayload");

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  pthread_mutex_lock(&dbConnMtx);

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  pthread_mutex_unlock(&dbConnMtx);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

exit_point:

  if (jsonParms)
  {
    cJSON_Delete(jsonParms);
    responsePayload = NULL;
  }

  return rc;
}

int setVmHostOffline(void)
{
cJSON *jsonParms = NULL, *item = NULL;
int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "setVmHostOffline");
  if (!item) return E_JSON_ERROR;

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }
  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);
  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}

// Yes...this violates the pattern in order to simplify specifying multiple IP addresses/devices. JSON is very convenient sometimes!

int validateVmState(void *vjsonParms)
{
int rc = E_SUCCESS;
cJSON *jsonParms = (cJSON *)vjsonParms;

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc) return E_MALLOC;

  logOutput(LOG_OUTPUT_ALWAYS, jsonParametersStr);

  pthread_mutex_lock(&dbConnMtx);

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  pthread_mutex_unlock(&dbConnMtx);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) return errorHandler(rc, dbSess.oraError);

  return rc;
}

int getMsgForVmHostMonitor(void)
{
int rc = OCI_SUCCESS;
cJSON *item = NULL, *jsonData = NULL;

retry:

  bzero(clientHandle, sizeof(clientHandle));
  messageType = 0;

  rc = OCIStmtExecute(qSess.oraSvcCtx, qConnStmt, qSess.oraError, 1, 0, NULL, NULL, OCI_DEFAULT);
  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc)
  {
    errorHandler(rc, qSess.oraError);

    if (OCI_QUEUE_TIMEOUT == oraErrorCode) goto retry;

    if (OCI_EOF_COM_CHAN == oraErrorCode || OCI_LOST_CONTACT == oraErrorCode || OCI_NOT_CONNECTED == oraErrorCode)
    {
      rc = reEstablishQueueConnection();
      if (rc) return E_FATAL_QUEUE_ERROR;

      goto retry;
    }

    if (OCI_ARRAY_DQ_FAIL == oraErrorCode && strstr(getOraErrorText(), OCI_CANCEL_OPERATION_TEXT))
      return E_STOP_QUEUE_THREAD;

    return(E_FATAL_QUEUE_ERROR);
  }

  jsonData = cJSON_Parse(queueData);

  rc = E_JSON_ERROR;

  item = cJSON_GetObjectItemCaseSensitive(jsonData, "clientHandle");
  if (!item) goto exit_point;
  strncpy(clientHandle, item->valuestring, sizeof(clientHandle) - 1);

  item = cJSON_GetObjectItemCaseSensitive(jsonData, "messageType");
  if (!item) goto exit_point;
  messageType = item->valueint;

  item = cJSON_GetObjectItemCaseSensitive(jsonData, "messagePayload");
  if (item && !cJSON_IsNull(item))
  {
    messagePayload = cJSON_Parse(item->valuestring);
    if (!messagePayload)
    {
      rc = jsonError("Unable to create messagePayload object.");
      goto exit_point;
    }
  }

  rc = E_SUCCESS;

exit_point:

  if (jsonData) cJSON_Delete(jsonData);
  return rc;
}

int breakDqSession(void)
{
int rc = E_SUCCESS;

  OCIBreak(qSess.oraSvcCtx, qSess.oraError);
  if (rc) errorHandler(rc, qSess.oraError);

  OCIReset(qSess.oraSvcCtx, qSess.oraError);
  if (rc) errorHandler(rc, qSess.oraError);

  return E_SUCCESS;
}

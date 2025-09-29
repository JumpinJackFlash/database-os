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

#include "vmHostMonitorDefs.h"
#include "vmHostMonitor.h"
#include "errors.h"
#include "logger.h"
#include "memory.h"

typedef struct
{
  OCISession    *oraSession;
  OCIAuthInfo   *authInfo;
  OCISvcCtx     *oraSvcCtx;
  OCIError      *oraError;
  char          username[DB_NAME_LENGTH];
  char          password[DB_NAME_LENGTH];
} OCI_SESSION;

typedef struct
{
  OCIEnv        *oraEnv;
  OCIServer     *oraServer;
  OCICPool      *connectionPool;
  OCISPool      *sessionPool;
  OraText       *poolName;
  sb4           poolNameLength;
  char          database[DB_NAME_LENGTH];
} OCI_CONNECTION;

static OCI_CONNECTION dbConn;                                                 // Main thread connection.
static OCI_CONNECTION qConn;

static OCI_SESSION qSess;
static OCI_SESSION dbSess;

static char jsonParametersStr[16384];

static int jsonResultStrLength = 8192;
char *jsonResultStr = NULL;

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
static int sessionCount = 0;

char clientHandle[CLIENT_HANDLE_LENGTH];
cJSON *messagePayload = NULL;
cJSON *responsePayload = NULL;
int messageType;

char oraErrorText[ORA_ERROR_TEXT_LENGTH];

static int oraErrorHandler(int rc, OCIError *error)
{
  switch((sword) rc)
  {
    case OCI_SUCCESS:
      return E_SUCCESS;

    case OCI_NEED_DATA:
      return E_SUCCESS;

    case OCI_NO_DATA:
      OCIErrorGet ((dvoid *) error, (ub4) 1, (text *) NULL, &oraErrorCode,
                    (OraText *)oraErrorText, (ub4) sizeof(oraErrorText), (ub4) OCI_HTYPE_ERROR);
      if ('\n' == oraErrorText[strlen(oraErrorText)-1])
        oraErrorText[strlen(oraErrorText)-1] = '\0';
      return E_NO_DATA;

    case OCI_SUCCESS_WITH_INFO:
      OCIErrorGet ((dvoid *) error, (ub4) 1, (text *) NULL, &oraErrorCode,
                    (OraText *)oraErrorText, (ub4) sizeof(oraErrorText), (ub4) OCI_HTYPE_ERROR);
      if ('\n' == oraErrorText[strlen(oraErrorText)-1])
        oraErrorText[strlen(oraErrorText)-1] = '\0';
      return E_SUCCESS;

    case OCI_ERROR:
      OCIErrorGet ((dvoid *) error, (ub4) 1, (text *) NULL, &oraErrorCode,
                    (OraText *)oraErrorText, (ub4) sizeof(oraErrorText), (ub4) OCI_HTYPE_ERROR);
      if ('\n' == oraErrorText[strlen(oraErrorText)-1])
        oraErrorText[strlen(oraErrorText)-1] = '\0';
      return E_OCI_ERROR;

    case OCI_INVALID_HANDLE:
        strncpy(oraErrorText, "Invalid handle.", sizeof(oraErrorText)-1);
      return E_OCI_ERROR;

    case OCI_STILL_EXECUTING:
      return E_SUCCESS;

    case OCI_CONTINUE:
      return E_SUCCESS;

    default:
      OCIErrorGet ((dvoid *) error, (ub4) 1, (text *) NULL, &oraErrorCode,
                    (OraText *)oraErrorText, (ub4) sizeof(oraErrorText), (ub4) OCI_HTYPE_ERROR);
      if ('\n' == oraErrorText[strlen(oraErrorText)-1])
        oraErrorText[strlen(oraErrorText)-1] = '\0';
      return E_OCI_ERROR;
  }
}

static char *getOraErrorText(void)
{
  return oraErrorText;
}

int getOraErrorCode(void)
{
  return (int) oraErrorCode;
}

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

int getSessionFromSPool(OCI_CONNECTION *cObj, OCI_SESSION *sObj)
{
sword rc = OCI_SUCCESS;

  rc = OCIHandleAlloc(cObj->oraEnv, (void *)&sObj->oraError, OCI_HTYPE_ERROR, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCIHandleAlloc(cObj->oraEnv, (void *)&sObj->authInfo, OCI_HTYPE_AUTHINFO, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCISessionGet(cObj->oraEnv, sObj->oraError, &sObj->oraSvcCtx, sObj->authInfo, cObj->poolName,
      cObj->poolNameLength, 0, 0, 0, 0, 0, OCI_SESSGET_SPOOL);
  if (rc) return oraErrorHandler(rc, sObj->oraError);

  sessionCount++;

  return rc;
}

static int connectToOracleAction(OCI_CONNECTION *cObj)
{
sword rc = OCI_SUCCESS;
OCIError *oraError = NULL;

  rc = OCIEnvCreate(&cObj->oraEnv, OCI_THREADED|OCI_OBJECT, (dvoid *)0, 0, 0, 0, (size_t) 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCIHandleAlloc(cObj->oraEnv, (void *)&cObj->oraServer, OCI_HTYPE_SERVER, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCIHandleAlloc(cObj->oraEnv, (void *)&oraError, OCI_HTYPE_ERROR, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCIServerAttach(cObj->oraServer, oraError, (OraText *)cObj->database, (sb4)strlen(cObj->database), OCI_DEFAULT);
  if (rc)
  {
    oraErrorHandler(rc, oraError);
    OCIHandleFree(oraError, OCI_HTYPE_ERROR);
    return E_OCI_ERROR;
  }

  if (oraError) rc = OCIHandleFree(oraError, OCI_HTYPE_ERROR);
  if (rc) return oraErrorHandler(rc, oraError);

  return E_SUCCESS;
}

static int reEstablishQueueConnection(void)
{
int rc = E_SUCCESS;

  rc = getSessionFromSPool(&dbConn, &qSess);
  if (rc) return errorHandler(rc, NULL);

  logOutput(LOG_OUTPUT_WARN, "Queue connection re-established.");

  return rc;
}

static int createOracleSession(OCI_CONNECTION *cObj, OCI_SESSION *sObj)
{
sword rc = OCI_SUCCESS;

  rc = OCIHandleAlloc(cObj->oraEnv, (void*)&sObj->oraError, OCI_HTYPE_ERROR, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);
  rc = OCIHandleAlloc(cObj->oraEnv, (void*)&sObj->oraSvcCtx, OCI_HTYPE_SVCCTX, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);
  rc = OCIAttrSet(sObj->oraSvcCtx, OCI_HTYPE_SVCCTX, cObj->oraServer, (ub4) 0, OCI_ATTR_SERVER, sObj->oraError);
  if (rc) return oraErrorHandler(rc, sObj->oraError);
  rc = OCIHandleAlloc(cObj->oraEnv, (void*)&sObj->oraSession, OCI_HTYPE_SESSION, 0, (dvoid **) 0);
  if (rc) return oraErrorHandler(rc, NULL);
  rc = OCIAttrSet(sObj->oraSession, OCI_HTYPE_SESSION, (OraText *)sObj->username, (sb4)strlen(sObj->username),
    OCI_ATTR_USERNAME, sObj->oraError);
  if (rc) return oraErrorHandler(rc, sObj->oraError);
  rc = OCIAttrSet(sObj->oraSession, OCI_HTYPE_SESSION, (OraText *)sObj->password,
    (sb4)strlen(sObj->password), OCI_ATTR_PASSWORD, sObj->oraError);
  if (rc) return oraErrorHandler(rc, sObj->oraError);

  rc = OCISessionBegin(sObj->oraSvcCtx, sObj->oraError, sObj->oraSession, OCI_CRED_RDBMS, OCI_DEFAULT);
  if (rc)
  {
    oraErrorHandler(rc, sObj->oraError);
    if (OCI_SUCCESS_WITH_INFO != rc) return(E_OCI_ERROR);
  }

  rc = OCIAttrSet(sObj->oraSvcCtx, OCI_HTYPE_SVCCTX, sObj->oraSession, (ub4) 0, OCI_ATTR_SESSION, sObj->oraError);
  if (rc) return oraErrorHandler(rc, sObj->oraError);

  return E_SUCCESS;
}

static int dropOracleSession(OCI_SESSION *sObj)
{
sword rc = OCI_SUCCESS;

  rc = OCISessionEnd(sObj->oraSvcCtx, sObj->oraError, sObj->oraSession, OCI_DEFAULT);
  if (rc) return oraErrorHandler(rc, sObj->oraError);
  if (sObj->oraSession) rc = OCIHandleFree(sObj->oraSession, OCI_HTYPE_SESSION);
  if (rc) return oraErrorHandler(rc, sObj->oraError);
  if (sObj->oraSvcCtx) rc = OCIHandleFree(sObj->oraSvcCtx, OCI_HTYPE_SVCCTX);
  if (rc) return oraErrorHandler(rc, sObj->oraError);
  if (sObj->oraError) rc = OCIHandleFree(sObj->oraError, OCI_HTYPE_ERROR);
  if (rc) return oraErrorHandler(rc, sObj->oraError);

  return E_SUCCESS;
}

static int disconnectFromOracleAction(OCI_CONNECTION *cObj)
{
sword rc = OCI_SUCCESS;
OCIError *oraError = NULL;

  rc = OCIHandleAlloc(cObj->oraEnv, (void*)&oraError, OCI_HTYPE_ERROR, 0, (dvoid **)0);
  if (rc) return oraErrorHandler(rc, NULL);

  rc = OCIServerDetach(cObj->oraServer, oraError, OCI_DEFAULT);
  if (rc) return oraErrorHandler(rc, oraError);
  if (cObj->oraServer) rc = OCIHandleFree(cObj->oraServer, OCI_HTYPE_SERVER);
  if (rc) return oraErrorHandler(rc, NULL);
  if (oraError) rc = OCIHandleFree(oraError, OCI_HTYPE_ERROR);
  if (rc) return oraErrorHandler(rc, NULL);
  if (cObj->oraEnv) rc = OCITerminate(OCI_DEFAULT);
  if (rc) return oraErrorHandler(rc, NULL);

  return E_SUCCESS;
}

int connectToDatabase(char *hostName)
{
int rc = E_SUCCESS;
cJSON *jsonParms = NULL, *item = NULL;

  jsonResultStr = allocateMemory(jsonResultStrLength);

  logOutput(LOG_OUTPUT_ALWAYS, "Connecting to the database...");

  strncpy(dbConn.database, envDatabaseName ? envDatabaseName : configDatabaseName, sizeof(dbConn.database)-1);
  dbConn.database[sizeof(dbConn.database)-1] = '\0';
  rc = connectToOracleAction(&dbConn);
  if (rc) return errorHandler(rc, NULL);

  strncpy(qConn.database, envDatabaseName ? envDatabaseName : configDatabaseName, sizeof(qConn.database)-1);
  qConn.database[sizeof(qConn.database)-1] = '\0';
  rc = connectToOracleAction(&qConn);
  if (rc) return errorHandler(rc, NULL);

  strncpy(qSess.username, envUser ? envUser : configUser, sizeof(qSess.username)-1);
  qSess.username[sizeof(qSess.username)-1] = '\0';
  strncpy(qSess.password, envPassword ? envPassword : configPassword, sizeof(qSess.password)-1);
  qSess.password[sizeof(qSess.password)-1] = '\0';
  rc = createOracleSession(&qConn, &qSess);
  if (rc) return errorHandler(rc, NULL);

  strncpy(dbSess.username, envUser ? envUser : configUser, sizeof(dbSess.username)-1);
  dbSess.username[sizeof(dbSess.username)-1] = '\0';
  strncpy(dbSess.password, envPassword ? envPassword : configPassword, sizeof(dbSess.password)-1);
  dbSess.password[sizeof(dbSess.password)-1] = '\0';
  rc = createOracleSession(&dbConn, &dbSess);
  if (rc) return errorHandler(rc, NULL);

  rc = OCIHandleAlloc(dbConn.oraEnv, (void *)&dbConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);
  rc = OCIHandleAlloc(qConn.oraEnv, (void *)&qConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);

  rc = OCIStmtPrepare2(dbSess.oraSvcCtx, &dbConnStmt, dbSess.oraError, (const OraText *)callApiTxt,
    (ub4) strlen(callApiTxt), (const OraText *) NULL, (ub4) 0, OCI_NTV_SYNTAX, OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIBindByName(dbConnStmt, &hostNameBV, dbSess.oraError, (const OraText *)":hostName", -1,
    hostName, (ub4) strlen(hostName)+1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
    (ub4 *) 0, (sb4) OCI_DEFAULT);
  if (rc) return errorHandler(rc, dbSess.oraError);

  rc = OCIBindByName(dbConnStmt, &jsonResultBV, dbSess.oraError, (const OraText *)":jsonResult", -1,
    jsonResultStr, (ub4) jsonResultStrLength - 1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
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
    hostName, (ub4) strlen(hostName)+1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
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

  if (jsonResultStr) freeMemory(jsonResultStr);

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
char *jsonString = NULL;
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

  jsonString = cJSON_PrintUnformatted(jsonParms);
  if (!jsonString)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonString, (ub4) strlen(jsonString)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);
  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

  if (jsonString) free(jsonString);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}

int updateLifecycleState(char *machineName, char *lifecycleState, char *detail)
{
cJSON *jsonParms = NULL, *item = NULL;
int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "updateLifecycleState");
  if (!item) return jsonError("entryPoint");

  item = cJSON_AddStringToObject(jsonParms, "clientHandle", clientHandle);
  if (!item) return jsonError("clientHandle");

  item = cJSON_AddStringToObject(jsonParms, "machineName", machineName);
  if (!item) return jsonError("machineName");

  item = cJSON_AddStringToObject(jsonParms, "lifecycleState", lifecycleState);
  if (!item) return jsonError("lifecycleState");

  item = cJSON_AddStringToObject(jsonParms, "detail", detail);
  if (!item) return jsonError("detail");

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  logOutput(LOG_OUTPUT_VERBOSE, jsonParametersStr);

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

int validateVmState(const char *domainName, const char *stateText)
{
int rc = E_SUCCESS;
cJSON *jsonParms = NULL, *item = NULL;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "validateVmState");
  if (!item)
  {
    rc = jsonError("entryPoint");
    goto exit_point;
  }

  item = cJSON_AddStringToObject(jsonParms, "machineName", domainName);
  if (!item)
  {
    rc = jsonError("domainName");
    goto exit_point;
  }

  item = cJSON_AddStringToObject(jsonParms, "lifecycleState", stateText);
  if (!item)
  {
    rc = jsonError("lifecycleState");
    goto exit_point;
  }

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  logOutput(LOG_OUTPUT_ALWAYS, jsonParametersStr);

  pthread_mutex_lock(&dbConnMtx);

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  pthread_mutex_unlock(&dbConnMtx);

  exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) return errorHandler(rc, dbSess.oraError);

  return rc;
}

int updateVmState(const char *domainName, const char *stateText)
{
int rc = E_SUCCESS;
cJSON *jsonParms = NULL, *item = NULL;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "updateVmState");
  if (!item)
  {
    rc = jsonError("entryPoint");
    goto exit_point;
  }

  item = cJSON_AddStringToObject(jsonParms, "machineName", domainName);
  if (!item)
  {
    rc = jsonError("domainName");
    goto exit_point;
  }

  item = cJSON_AddStringToObject(jsonParms, "lifecycleState", stateText);
  if (!item)
  {
    rc = jsonError("lifecycleState");
    goto exit_point;
  }

  rc = cJSON_PrintPreallocated(jsonParms, jsonParametersStr, sizeof(jsonParametersStr), 0);
  if (!rc)
  {
    rc = E_MALLOC;
    goto exit_point;
  }

  logOutput(LOG_OUTPUT_ALWAYS, jsonParametersStr);

  retry:

  pthread_mutex_lock(&dbConnMtx);

  rc = OCIBindByName(dbConnStmt, &jsonParmsBV, dbSess.oraError,
    (const OraText *)":jsonParameters", -1, jsonParametersStr, (ub4) strlen(jsonParametersStr)+1,
    SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0, (ub4 *) 0, (sb4) OCI_DEFAULT);

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  pthread_mutex_unlock(&dbConnMtx);

  if (OCI_PACKAGE_STATE_DISCARDED == rc) goto retry;

  exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) return errorHandler(rc, dbSess.oraError);

  return rc;
}

// Yes...this violates the pattern in order to simplify specifying multiple IP addresses/devices. JSON is very convenient sometimes!

int updateVmInfo(void *vjsonParms)
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

    if (OCI_QUEUE_TIMEOUT == oraErrorCode || OCI_PACKAGE_STATE_DISCARDED == oraErrorCode) goto retry;

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

int updateVmXMLDescription(char *machineName, char *xmlDescription)
{
  cJSON *jsonParms = NULL, *item = NULL;
  int rc = E_SUCCESS;

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "updateVMDescription");
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "machineName", machineName);
  if (!item) return jsonError("machineName");

  item = cJSON_AddStringToObject(jsonParms, "xmlDescription", xmlDescription);
  if (!item) return jsonError("detail");

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
  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc) rc = errorHandler(rc, dbSess.oraError);

  pthread_mutex_unlock(&dbConnMtx);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}

int getVmXMLDescription(int virtualMachineId, int xmlDescriptionLength)
{
cJSON *jsonParms = NULL, *item = NULL;
int rc = E_SUCCESS, newJsonResultStrLength = xmlDescriptionLength + 256;

  if (jsonResultStrLength < newJsonResultStrLength)
  {
    jsonResultStr = (char *) reallocateMemory(jsonResultStr, jsonResultStrLength, newJsonResultStrLength);
    jsonResultStrLength = newJsonResultStrLength;

    rc = OCIBindByName(dbConnStmt, &jsonResultBV, dbSess.oraError, (const OraText *)":jsonResult", -1,
      jsonResultStr, (ub4) jsonResultStrLength - 1, SQLT_STR, NULL, (ub2 *)0, (ub2 *)0, (ub4) 0,
      (ub4 *) 0, (sb4) OCI_DEFAULT);
    if (rc) return errorHandler(rc, dbSess.oraError);
  }

  jsonParms = cJSON_CreateObject();
  if (!jsonParms) return E_JSON_ERROR;

  item = cJSON_AddStringToObject(jsonParms, "entryPoint", "getVirtualMachineDescription");
  if (!item) return E_JSON_ERROR;

  item = cJSON_AddNumberToObject(jsonParms, "virtualMachineId", (double) virtualMachineId);
  if (!item) return jsonError("virtualMachineId");

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

retry:

  rc = OCIStmtExecute(dbSess.oraSvcCtx, dbConnStmt, dbSess.oraError, 1, 0, NULL, NULL,
    OCI_COMMIT_ON_SUCCESS);

  if (rc && OCI_SUCCESS_WITH_INFO != rc && OCI_NO_DATA != rc)
  {
    rc = errorHandler(rc, dbSess.oraError);
    if (OCI_PACKAGE_STATE_DISCARDED == oraErrorCode) goto retry;
  }

  pthread_mutex_unlock(&dbConnMtx);

exit_point:

  if (jsonParms) cJSON_Delete(jsonParms);

  return rc;
}


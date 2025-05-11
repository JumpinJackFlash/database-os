/*
 * oraDataLayer.c
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <oci.h>

#include <cjson/cJSON.h>

#include <commonDefs.h>
#include <oraCommon.h>

static OCI_CONNECTION   dbConn;                                                 // Main thread connection.
static OCI_CONNECTION   qConn;

static OCI_SESSION qSess;
static OCI_SESSION dbSess;

static char jsonParametersStr[8192];

static char jsonResultStr[8192];

static char *callRuntimeApiTxt = "begin :jsonResult := vm_hostmon_api.call_api(:jsonParameters); end;";

static OCIStmt *dbConnStmt = NULL;
static OCIStmt *qConnStmt = NULL;

static OCIBind *jsonParametersBV = NULL;
static OCIBind *jsonResultBV = NULL;

static sb4 oraErrorCode = OCI_SUCCESS;

char clientHandle[CLIENT_HANDLE_LENGTH];
int messageType;

static int oraCommonErrorHandler(void)
{
  logOutput(LOG_OUTPUT_ERROR, getOraErrorText());
  return E_OCI_ERROR;
}

int connectToDatabase(void)
{
int rc = E_SUCCESS;

  logOutput(LOG_OUTPUT_ALWAYS, "Connecting to the database...");

  bzero(&dbConn, sizeof(dbConn));
  osStrcpy(dbConn.database, databaseName, sizeof(dbConn.database));
  rc = connectToOracleAction(&dbConn);
  if (rc) return oraCommonErrorHandler();

  bzero(&qConn, sizeof(qConn));
  osStrcpy(qConn.database, databaseName, sizeof(qConn.database));
  rc = connectToOracleAction(&qConn);
  if (rc) oraCommonErrorHandler();

  bzero(&qSess, sizeof(qSess));
  osStrcpy(qSess.username, runtimeUser, sizeof(qSess.username));
  osStrcpy(qSess.password, runtimePassword, sizeof(qSess.password));
  rc = createOracleSession(&qConn, &qSess);
  if (rc) return oraCommonErrorHandler();

  bzero(&dbSess, sizeof(OCI_SESSION));
  osStrcpy(dbSess.username, runtimeUser, sizeof(dbSess.username));
  osStrcpy(dbSess.password, runtimePassword, sizeof(dbSess.password));
  rc = createOracleSession(&dbConn, &dbSess);
  if (rc) return oraCommonErrorHandler();

  rc = OCIHandleAlloc(dbConn.oraEnv, (void *)&dbConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);
  rc = OCIHandleAlloc(qConn.oraEnv, (void *)&qConnStmt, OCI_HTYPE_STMT, 0, (dvoid **)0);

  rc = OCIStmtPrepare(dbConnStmt, dbSess.oraError, (const OraText *)callRuntimeApiTxt,
    (ub4) strlen(callRuntimeApiTxt), OCI_NTV_SYNTAX, OCI_DEFAULT);

  rc = OCIStmtPrepare(qConnStmt, dbSess.oraError, (const OraText *)callRuntimeApiTxt,
    (ub4) strlen(callRuntimeApiTxt), OCI_NTV_SYNTAX, OCI_DEFAULT);

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
  return E_SUCCESS;
}


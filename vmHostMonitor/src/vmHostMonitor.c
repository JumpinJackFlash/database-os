/*
 *
 * Copyright 2020 and beyond by AsterionDB, Inc.  All rights reserved
 *
 * A derivative of the DbPluginServer
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <sys/prctl.h>

#include "commonDefs.h"

#include "vmHostMonitorDefs.h"
#include "dataLayer.h"
#include "vmHosts.h"

static char configFile[MAXPATH];
static char configFilePath[MAXPATH];
static int daemonize = FALSE;
static char text2Log[LOGMSG_LENGTH];

static int processCommandLine(int argc, char *argv[])
{
  osStrcpy(configFile, CONFIG_FILE, sizeof(configFile));

  if (2 == argc) osStrcpy(configFile, argv[1], sizeof(configFile));

  return(E_SUCCESS);
}

static void setLocationOfConfigFile(char *configFileName)
{
  if (!osStrcasecmp(configFileName, CONFIG_FILE))
    osSprintf(configFilePath, sizeof(configFilePath), "%s%cconfig%c%s", homeDirectory, DIRECTORY_SEPARATOR,
      DIRECTORY_SEPARATOR, configFileName);
  else
    osStrcpy(configFilePath, configFileName, sizeof(configFilePath));
}

static int storeConfigOption(char *option, char *value)
{
int rc = E_SUCCESS;

  if (!osStrcasecmp("username", option))
  {
    if (runtimeUser[0]) return E_SUCCESS;
    if (!value) return E_CONFIG_OPTION_VALUE;
    if (strlen(value) > sizeof(runtimeUser))
      return E_CONFIG_OPTION_VALUE;

    osStrcpy(runtimeUser, value, sizeof(runtimeUser));
    return(rc);
  }

  if (!osStrcasecmp("password", option))
  {
    if (runtimePassword[0]) return E_SUCCESS;
    if (!value) return E_CONFIG_OPTION_VALUE;
    if (strlen(value) > sizeof(runtimePassword))
      return E_CONFIG_OPTION_VALUE;

    osStrcpy(runtimePassword, value, sizeof(runtimePassword));
    return(rc);
  }

  if (!osStrcasecmp("database", option))
  {
    if (databaseName[0]) return E_SUCCESS;
    if (!value) return rc;

    if (strlen(value) > sizeof(databaseName))
      return E_CONFIG_OPTION_VALUE;

    osStrcpy(databaseName, value, sizeof(databaseName));
    return(rc);
  }

  if (!osStrcasecmp("daemonize", option))
  {
    if (!value) return rc;

    if (!osStrcasecmp("TRUE", value))
      daemonize = TRUE;
    else
      daemonize = FALSE;

    return rc;
  }

  if (!osStrcasecmp("logLevel", option))
  {
      setLogLevel(atoi(value));
      return rc;
  }

  logOutput(LOG_OUTPUT_ERROR, option);
  return E_CONFIG_OPTION;
}

static int parseConfigOptions(void)
{
char *option = NULL, *value = NULL;
int rc = E_SUCCESS;

  logOutput(LOG_OUTPUT_INFO, "Processing configuration options.");

  while (E_EOF != getNextConfigurationOption(&option, &value))
  {
    rc = storeConfigOption(option, value);
    if (rc) return rc;
  }

  return E_SUCCESS;
}


static int processConfigFile(void)
{
int rc = E_SUCCESS;

  rc = openConfigFile(configFilePath);
  if (rc) return(rc);

  rc = parseConfigOptions();
  closeConfigFile();

  return(rc);
}

static void demonize(int daemonize)
{
int rc = E_SUCCESS;

  if (daemonize)
  {
    logOutput(LOG_OUTPUT_ALWAYS, "The database plugin server is now running as a background process.");
    rc = osDaemonize();
    if (rc)
    {
      osSprintf(text2Log, sizeof(text2Log), "daemon failed...%d - %s", rc, strerror(errno));
      osSprintf(text2Log, sizeof(text2Log), "daemon failed...%d", rc);
      logOutput(LOG_OUTPUT_ERROR, text2Log);
      osErrorHandler(E_FATAL_SERVER_ERROR);
    }
  }
}

int main(int argc, char *argv[])
{
int rc = E_SUCCESS;

  startupPreamble(PROGRAM_NAME, __DATE__, __TIME__);

  rc = processCommandLine(argc, argv);
  if (rc) goto exitPoint;

  rc = getEnvironmentVariables();
  if (rc) goto exitPoint;

  setLocationOfConfigFile(configFile);
  rc = processConfigFile();
  if (rc) goto exitPoint;

  rc = openLogFile(PROGRAM_NAME, homeDirectory);
  if (rc) goto exitPoint;
  writePreambleToLogfile(PROGRAM_NAME, __DATE__, __TIME__);
  osSprintf(text2Log, sizeof(text2Log), "Opening configuration file: %s", configFilePath);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  rc = createPidFile(PROGRAM_NAME);
  if (rc) goto exitPoint;

  rc = startSystemdHeartbeat();
  if (rc) goto exitPoint;

  demonize(daemonize);                                       // No-op in WinDoze....

  prctl(PR_SET_DUMPABLE, 1);

  rc = connectToDatabase();
  if (rc) goto exitPoint;

  snprintf(text2Log, sizeof(text2Log), "%s is online...", PROGRAM_NAME);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  rc = connectToVmHost();

  disconnectFromVmHost();

exitPoint:

  if (rc) logOutput(LOG_OUTPUT_ERROR, getDbPluginErrorText(rc));

  terminateSystemdHeartbeat();

  closeStatementHandles();

  disconnectFromDatabase();

  snprintf(text2Log, sizeof(text2Log), "%s shutdown complete...", PROGRAM_NAME);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  closeLogFile();

  removePidFile();

  return rc;
}

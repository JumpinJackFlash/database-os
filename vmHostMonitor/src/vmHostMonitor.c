/*
 *
 * Copyright 2025 and beyond by AsterionDB, Inc.  All rights reserved
 *
 * A derivative of the DbPluginServer
 *
 * For debugging purposes, set keepalive_interval = -1 in /etc/libvirt/virtqemud.conf and then systemctl restart virtqemud.
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <signal.h>
#include <pthread.h>
#include <sys/prctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <systemd/sd-daemon.h>

#include <cjson/cJSON.h>

#include "vmHostMonitorDefs.h"
#include "oraDataLayer.h"
#include "vmHosts.h"
#include "dbQueueMonitor.h"
#include "errors.h"
#include "logger.h"

static char cmdLineConfigFile[PATH_MAX];
static char configFilePath[PATH_MAX];
static int daemonize = FALSE;
static char text2Log[LOGMSG_LENGTH];

static FILE *configFile = NULL;
static char workArea[WORK_LENGTH], inputLine[WORK_LENGTH];

static pthread_t heartbeatThreadID = 0;
static char heartbeatTerminated = FALSE;
static uint64_t systemdTimeout = 0;

char pidFilename[PATH_MAX];
int pidFile = 0;

char configUser[DB_NAME_LENGTH];
char configPassword[DB_NAME_LENGTH];
char configOracleHome[PATH_MAX];
char configDatabaseName[DB_NAME_LENGTH];

char *homeDirectory;
char *envUser;
char *envPassword;
char *envDatabaseName;
char *envOracleHome;

char hostName[HOST_NAME_MAX];

int openConfigFile(char *configFilePath)
{
  configFile = fopen(configFilePath, "rt");
  if (!configFile) return(E_CONFIG_FILE);
  return(E_SUCCESS);
}

void closeConfigFile(void)
{
  fclose(configFile);
  return;
}

int getNextConfigurationOption(char **optionName, char **optionValue)
{
char *option = NULL, *value = NULL;

  while (fgets(inputLine, sizeof(inputLine), configFile))
  {
    strncpy(workArea, inputLine, sizeof(workArea)-1);
    workArea[sizeof(workArea)-1] = '\0';
    option = strtok(workArea, " \t\n\r");
    if (option && ';' != *option)
    {
      *optionName = option;

      value = strtok(NULL, " \t\n\r");
      if (!value) return E_SUCCESS;
      *optionValue = value;
      return E_SUCCESS;
    }
  }
  return E_EOF;
}

char *getConfigInputLine(void)
{
  return inputLine;
}

static int getEnvironmentVariables(void)
{
  homeDirectory = getenv(HOME_ENVAR);
  if (!homeDirectory) return E_ENVVAR;

  envUser = getenv(RUNTIME_USER_ENVAR);
  envPassword = getenv(RUNTIME_PASSWORD_ENVAR);
  envDatabaseName = getenv(DATABASE_NAME_ENVAR);
  envOracleHome = getenv(ORACLE_HOME_ENVAR);

  return E_SUCCESS;
}

static int processCommandLine(int argc, char *argv[])
{
  if (2 == argc)
  {
    strncpy(cmdLineConfigFile, argv[1], sizeof(cmdLineConfigFile)-1);
    cmdLineConfigFile[sizeof(cmdLineConfigFile)-1] = '\0';
  }

  return(E_SUCCESS);
}

static int storeConfigOption(char *option, char *value)
{
int rc = E_SUCCESS;

  if (!strcasecmp("username", option))
  {
    if (envUser) return E_SUCCESS;  // We're using the enviro var val.
    if (!value) return E_CONFIG_OPTION_VALUE;
    if (strlen(value) > sizeof(configUser)-1)
      return E_CONFIG_OPTION_VALUE;

    strncpy(configUser, value, sizeof(configUser)-1);
    configUser[sizeof(configUser)-1] = '\0';
    return(rc);
  }

  if (!strcasecmp("password", option))
  {
    if (envPassword) return E_SUCCESS;
    if (!value) return E_CONFIG_OPTION_VALUE;
    if (strlen(value) > sizeof(configPassword)-1)
      return E_CONFIG_OPTION_VALUE;

    strncpy(configPassword, value, sizeof(configPassword)-1);
    configPassword[sizeof(configPassword)-1] = '\0';
    return(rc);
  }

  if (!strcasecmp("database", option))
  {
    if (envDatabaseName) return E_SUCCESS;
    if (!value) return rc;

    if (strlen(value) > sizeof(configDatabaseName)-1)
      return E_CONFIG_OPTION_VALUE;

    strncpy(configDatabaseName, value, sizeof(configDatabaseName)-1);
    configDatabaseName[sizeof(configDatabaseName)-1] = '\0';
    return(rc);
  }

  if (!strcasecmp("daemonize", option))
  {
    if (!value) return rc;

    if (!strcasecmp("TRUE", value))
      daemonize = TRUE;
    else
      daemonize = FALSE;

    return rc;
  }

  if (!strcasecmp("logLevel", option))
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

static void *heartbeatThread(void *dumbArg)
{
int rc = E_SUCCESS;
sigset_t signalSet;

stillAlive:

  sigemptyset(&signalSet);
  sigaddset(&signalSet, SIGINT);
  pthread_sigmask(SIG_BLOCK, &signalSet, NULL);

  sd_notify(FALSE, "WATCHDOG=1");

  sigemptyset(&signalSet);
  sigaddset(&signalSet, SIGINT);
  pthread_sigmask(SIG_UNBLOCK, &signalSet, NULL);

  rc = sleep(systemdTimeout);
  if (rc) return NULL;

  if (heartbeatTerminated) pthread_exit((void *) NULL);

  goto stillAlive;

  return NULL;
}

static int startSystemdHeartbeat(void)
{
  systemdTimeout = 0;

  sd_watchdog_enabled(FALSE, &systemdTimeout);
  if (!systemdTimeout) return E_SUCCESS;

  systemdTimeout *= USEC_TO_SEC_FACTOR;
  systemdTimeout -= (int) (systemdTimeout * WAKE_UP_EARLY_PERCENT);
  sprintf(sText2Log, "Watchdog/Heartbeat Interval: %ld", systemdTimeout);
  logOutput(LOG_OUTPUT_ALWAYS, sText2Log);

  return pthread_create(&heartbeatThreadID, NULL, heartbeatThread, (void *)NULL);
}

void terminateSystemdHeartbeat(void)
{
  if (!heartbeatThreadID) return;

  pthread_kill(heartbeatThreadID, SIGINT);
  pthread_join(heartbeatThreadID, NULL);
}

static void demonize(int daemonize)
{
int rc = E_SUCCESS;

  if (daemonize)
  {
    logOutput(LOG_OUTPUT_ALWAYS, "The VM Host Monitor is now running as a background process.");
    rc = daemon(FALSE, FALSE);
    if (rc)
    {
      snprintf(text2Log, sizeof(text2Log), "daemon failed...%d - %s", rc, strerror(errno));
      snprintf(text2Log, sizeof(text2Log), "daemon failed...%d", rc);
      logOutput(LOG_OUTPUT_ERROR, text2Log);
      logOutput(LOG_OUTPUT_ERROR, strerror(errno));
    }
  }
}

static int createPidFile(const char *programName)
{
  char pidX[MAX_PID_SIZE], pidDirectory[PATH_MAX], *x = NULL;
  size_t bytesRead = 0;
  __pid_t runningPid = 0;
  int rc = E_SUCCESS;

  snprintf(pidFilename, sizeof(pidFilename), "%s/%s.pid", PID_FILE_PREFIX, programName);
  snprintf(text2Log, sizeof(text2Log), "Opening PID file: %s", pidFilename);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  if (strchr(programName, '/'))
  {
    strcpy(pidDirectory, pidFilename);
    x = strrchr(pidDirectory, '/');
    *x = '\0';
    rc = mkdir(pidDirectory, S_IRWXU);
    if (rc && EEXIST != errno)
    {
      logOutput(LOG_OUTPUT_ERROR, strerror(errno));
      return E_CREATE_PID_FILE;
    }
  }

  pidFile = open(pidFilename, O_RDWR | O_CREAT | O_CLOEXEC, S_IRUSR | S_IWUSR);
  if (-1 == pidFile)
  {
    logOutput(LOG_OUTPUT_ERROR, strerror(errno));
    return E_CREATE_PID_FILE;
  }

  bzero(pidX, sizeof(pidX));
  bytesRead = read(pidFile, pidX, sizeof(pidX)-1);
  if (bytesRead)
  {
    runningPid = (__pid_t) atoi(pidX);
    if (runningPid)
    {
      if (!kill(runningPid, 0)) return E_CREATE_PID_FILE;
    }
  }

  bzero(pidX, sizeof(pidX));
  snprintf(pidX, sizeof(pidX), "%d", getpid());

  write(pidFile, pidX, strlen(pidX));

  return E_SUCCESS;
}

int rewritePidFile(void)
{
  char pidX[MAX_PID_SIZE];

  bzero(pidX, sizeof(pidX));
  snprintf(pidX, sizeof(pidX), "%d", getpid());

  lseek(pidFile, 0, SEEK_SET);
  write(pidFile, pidX, strlen(pidX));

  return E_SUCCESS;
}

void removePidFile(void)
{
  close(pidFile);
  unlink(pidFilename);
}

int main(int argc, char *argv[])
{
int rc = E_SUCCESS;

  startupPreamble(PROGRAM_NAME, __DATE__, __TIME__);

  rc = processCommandLine(argc, argv);
  if (rc) goto exitPoint;

  rc = getEnvironmentVariables();
  if (rc) goto exitPoint;

  snprintf(configFilePath, sizeof(configFilePath), "%s%cconfig%c%s", homeDirectory, DIRECTORY_SEPARATOR,
    DIRECTORY_SEPARATOR, cmdLineConfigFile[0] ? cmdLineConfigFile : CONFIG_FILE);
  configFilePath[sizeof(configFilePath)-1] = '\0';

  rc = processConfigFile();
  if (rc) goto exitPoint;

  gethostname(hostName, sizeof(hostName)-1);
  if (rc) return osErrorHandler(E_OSERR);
  if (rc) goto exitPoint;

  rc = openLogFile(PROGRAM_NAME, homeDirectory);
  if (rc) goto exitPoint;
  writePreambleToLogfile(PROGRAM_NAME, __DATE__, __TIME__);
  snprintf(text2Log, sizeof(text2Log), "Opening configuration file: %s", configFilePath);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  rc = createPidFile(PROGRAM_NAME);
  if (rc) goto exitPoint;

  rc = startSystemdHeartbeat();
  if (rc) goto exitPoint;

  demonize(daemonize);                                       // No-op in WinDoze....

  prctl(PR_SET_DUMPABLE, 1);

  rc = connectToDatabase(hostName);
  if (rc) goto exitPoint;

  snprintf(text2Log, sizeof(text2Log), "%s is online...", PROGRAM_NAME);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  rc = setupEventLoop();

  rc = connectToVmHost();
  if (rc) goto exitPoint;

  startQueueThread();

  rc = monitorDomainEvents();

  disconnectFromVmHost();

exitPoint:

  if (rc) logOutput(LOG_OUTPUT_ERROR, getErrorText(rc));

  terminateSystemdHeartbeat();

  stopQueueThread();
  closeStatementHandles();

  disconnectFromDatabase();

  snprintf(text2Log, sizeof(text2Log), "%s shutdown complete...", PROGRAM_NAME);
  logOutput(LOG_OUTPUT_ALWAYS, text2Log);

  closeLogFile();

  removePidFile();

  return rc;
}

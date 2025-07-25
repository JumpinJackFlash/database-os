#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <limits.h>
#include <unistd.h>
#include <sys/time.h>
#include <sys/stat.h>

#include "vmHostMonitorDefs.h"
#include "errors.h"

#define TIMESTAMP_SIZE                          27              // mm/dd/yyyy hh:mi:ss.ffffff

static FILE *logFile = NULL;

static int  logOutputToFile = FALSE;
static char logFileName[PATH_MAX];
static char logFilePath[PATH_MAX];
static int logLevel = LOG_OUTPUT_ERROR;

char sText2Log[LOGMSG_LENGTH+1];                            // Static to library...

static int stringifyTm(char *buffer, int bufferLen, struct tm *tmValue, long int micro)
{
char month[13], day[3], year[12], hour[3], minute[3], seconds[3], microSecs[7];

  if (TIMESTAMP_SIZE > bufferLen) return E_BUFFER_OVERFLOW;

  if (10 > (tmValue->tm_mon + 1))
    sprintf(month, "0%d", tmValue->tm_mon+1);
  else
    sprintf(month, "%d", tmValue->tm_mon+1);

  if (10 > tmValue->tm_mday)
    sprintf(day, "0%d", tmValue->tm_mday);
  else
    sprintf(day, "%d", tmValue->tm_mday);

  sprintf(year, "%d", tmValue->tm_year + 1900);

  if (10 > tmValue->tm_hour)
    sprintf(hour, "0%d", tmValue->tm_hour);
  else
    sprintf(hour, "%d", tmValue->tm_hour);

  if (10 > tmValue->tm_min)
    sprintf(minute, "0%d", tmValue->tm_min);
  else
    sprintf(minute, "%d", tmValue->tm_min);

  if (10 > tmValue->tm_sec)
    sprintf(seconds, "0%d", tmValue->tm_sec);
  else
    sprintf(seconds, "%d", tmValue->tm_sec);

  snprintf(microSecs, sizeof(microSecs)-1, "%ld", micro);

  sprintf(buffer, "%s/%s/%s %s:%s:%s.%s", month, day, year, hour, minute, seconds, microSecs);
  return E_SUCCESS;
}

static int timeStamp(char *timeStampValue, int timeStampValueLen)
{
struct timeval timeValue;

  gettimeofday(&timeValue, NULL);
  return stringifyTm(timeStampValue, timeStampValueLen, localtime(&timeValue.tv_sec), timeValue.tv_usec);
}

static void zPad(char *x)
{
char y;

  if (1 == strlen(x))
  {
    y = *x;
    *x++ = '0';
    *x++ = y;
    *x = '\0';
  }
  return;
}

static int logToScreenOnly(char *textToLog, int crlf)
{
char timeStampValue[TIMESTAMP_SIZE];

  timeStamp(timeStampValue, TIMESTAMP_SIZE);

  if (crlf)
    printf("%s - %s\n", timeStampValue, textToLog);
  else
    printf("%s - %s", timeStampValue, textToLog);

  return(E_SUCCESS);
}

static int createDirectory(char *fileName)
{
int rc = E_SUCCESS;

  rc = mkdir(fileName, 0755);
  if (-1 == rc && EEXIST != errno)
    return E_LOG_FILE_DIRECTORY;

  return E_SUCCESS;
}

static void writeToLogFile(char *output, int crlf)
{
char timeStampValue[TIMESTAMP_SIZE];

  timeStamp(timeStampValue, TIMESTAMP_SIZE);

  if (logFile)
  {
    if (crlf)
      fprintf(logFile, "%s - %s\n", timeStampValue, output);
    else
      fprintf(logFile, "%s - %s", timeStampValue, output);
  }

  return;
}

void logOutput(int pLogLevel, char *textToLog)
{
  if (pLogLevel > logLevel) return;

  logToScreenOnly(textToLog, TRUE);
  if (logOutputToFile) writeToLogFile(textToLog, TRUE);
}

void logOutputNoCRLF(int pLogLevel, char *textToLog)
{
  if (pLogLevel > logLevel) return;

  logToScreenOnly(textToLog, FALSE);
  if (logOutputToFile) writeToLogFile(textToLog, FALSE);
}

static void getLocalTime(void *vLocalTime)
{
time_t timeVal = 0;
struct tm *timeStruct = NULL, *x = (struct tm *) vLocalTime;

  timeVal = time(NULL);
  timeStruct = localtime(&timeVal);
  *x = *timeStruct;
  return;
}

int openLogFile(char *fileName, char *homeDirectory)
{
int rc = E_SUCCESS;
struct tm timeStruct;
char timeStamp[13], month[3], day[3], hour[3], minute[3];
char textToLog[WORK_LENGTH];

  getLocalTime(&timeStruct);

  snprintf(month, sizeof(month), "%d", 1 + timeStruct.tm_mon);
  zPad(month);
  snprintf(day, sizeof(day), "%d", timeStruct.tm_mday);
  zPad(day);
  snprintf(hour, sizeof(hour), "%d", timeStruct.tm_hour);
  zPad(hour);
  snprintf(minute, sizeof(minute), "%d", timeStruct.tm_min);
  zPad(minute);

  snprintf(timeStamp, sizeof(timeStamp), "%d%s%s%s%s", 1900 + timeStruct.tm_year, month,
    day, hour, minute);

  snprintf(logFileName, sizeof(logFileName), "%s%c%s", homeDirectory, DIRECTORY_SEPARATOR, "logs");

  rc = createDirectory(logFileName);
  if (rc)
  {
    logOutput(LOG_OUTPUT_ERROR, "Unable to create log file directory.");
    logOutput(LOG_OUTPUT_ERROR, logFileName);
    return osErrorHandler(rc);
  }

  snprintf(logFilePath, sizeof(logFilePath), "%s%c%s-%s-%d.log", logFileName, DIRECTORY_SEPARATOR, fileName, timeStamp, getpid());

  logFile = fopen(logFilePath, "wt");
  if (!logFile)
  {
    logOutput(LOG_OUTPUT_ERROR, "Unable to open log file");
    logOutput(LOG_OUTPUT_ERROR, logFilePath);
    return osErrorHandler(E_LOG_FILE);
  }

  logOutputToFile = TRUE;
  snprintf(textToLog, sizeof(textToLog), "Opened log file: %s", logFilePath);
  logToScreenOnly(textToLog, TRUE);

  setvbuf(logFile, (char *) NULL, _IOLBF, 0);

  return(rc);
}

char *getLogFileName(void)
{
  return logFilePath;
}

int closeLogFile(void)
{
int rc = E_SUCCESS;

  if (logFile) fclose(logFile);
  logFile = NULL;
  return(rc);
}

void writePreambleToLogfile(char *programName, char *buildDate, char *buildTime)
{
char textToLog[WORK_LENGTH];

  snprintf(textToLog, sizeof(textToLog), "%s - tag: %s - branch: %s", programName, GIT_TAG, GIT_BRANCH);
  writeToLogFile(textToLog, TRUE);
  snprintf(textToLog, sizeof(textToLog), "Build Date/Time: %s / %s", buildDate, buildTime);
  writeToLogFile(textToLog, TRUE);

  writeToLogFile("Copyright (c) 2025 by AsterionDB Inc. All rights reserved.", TRUE);
  writeToLogFile("The use of this software is governed by a software license", TRUE);
  writeToLogFile("agreement contained within the Software Development Kit", TRUE);
  writeToLogFile("distribution.  Consult that license document for further", TRUE);
  writeToLogFile("information.  Your continued use of this software confirms", TRUE);
  writeToLogFile("that you will abide by the terms of the license agreement.", TRUE);
}

void startupPreamble(char *programName, char *buildDate, char *buildTime)
{
char textToLog[WORK_LENGTH];

  snprintf(textToLog, sizeof(textToLog), "%s - tag: %s - branch: %s", programName, GIT_TAG, GIT_BRANCH);
  logOutput(LOG_OUTPUT_ALWAYS, textToLog);
  snprintf(textToLog, sizeof(textToLog), "Build Date/Time: %s / %s", buildDate, buildTime);
  logOutput(LOG_OUTPUT_ALWAYS, textToLog);

  logOutput(LOG_OUTPUT_ALWAYS, "Copyright (c) 2025 by AsterionDB Inc. All rights reserved.");
  logOutput(LOG_OUTPUT_ALWAYS, "The use of this software is governed by a software license");
  logOutput(LOG_OUTPUT_ALWAYS, "agreement contained within the Software Development Kit");
  logOutput(LOG_OUTPUT_ALWAYS, "distribution.  Consult that license document for further");
  logOutput(LOG_OUTPUT_ALWAYS, "information.  Your continued use of this software confirms");
  logOutput(LOG_OUTPUT_ALWAYS, "that you will abide by the terms of the license agreement.");
}

void setLogLevel(int pLogLevel)
{
  logLevel = pLogLevel;
}

int getLogLevel(void)
{
  return logLevel;
}

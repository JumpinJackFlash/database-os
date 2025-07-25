#ifndef LOGGER_H_
#define LOGGER_H_

void logOutput(int pLogLevel, char *textToLog);
void logOutputNoCRLF(int pLogLevel, char *textToLog);
int openLogFile(char *fileName, char *homeDirectory);
int closeLogFile(void);
void startupPreamble(char *programName, char *buildDate, char *buildTime);
void writePreambleToLogfile(char *programName, char *buildDate, char *buildTime);
char *getLogFileName(void);
void setLogLevel(int pLogLevel);
int getLogLevel(void);

extern char sText2Log[LOGMSG_LENGTH+1];             // Local to the library

#endif

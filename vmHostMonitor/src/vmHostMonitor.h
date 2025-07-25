/*
 * vmHostMonitor.h
 *
 *  Created on: Jun 13, 2025
 *      Author: gilly
 */

#ifndef VMHOSTMONITOR_H_
#define VMHOSTMONITOR_H_

extern char configUser[DB_NAME_LENGTH];
extern char configPassword[DB_NAME_LENGTH];
extern char configOracleHome[PATH_MAX];
extern char configDatabaseName[DB_NAME_LENGTH];

extern char *homeDirectory;
extern char *envUser;
extern char *envPassword;
extern char *envDatabaseName;
extern char *envOracleHome;

#endif /* VMHOSTMONITOR_H_ */

/*
 * dataLayer.h
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#ifndef ORADATALAYER_H_
#define ORADATALAYER_H_

extern int messageType;
extern cJSON *messagePayload;
extern cJSON *responsePayload;

int connectToDatabase(char *hostName);
int disconnectFromDatabase(void);
void closeStatementHandles(void);
int registerVmHost(char *sysInfo, char *hostCapabilities, unsigned long hypervisorVersion, unsigned long libvirtVersion,
  char *osRelease, char *machineType);
int setVmHostOffline(void);
int sendMessageToClient(void);
int updateLifecycleState(char *machineName, char *lifecycleState);
int updatePersistence(char *machineName, char *persistent);
int validateVmState(void *vjsonParms);
int updateVmState(void *vjsonParms);
int getMsgForVmHostMonitor(void);
int breakDqSession(void);

#endif /* ORADATALAYER_H_ */

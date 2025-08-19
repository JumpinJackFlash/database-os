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
extern char *jsonResultStr;

int connectToDatabase(char *hostName);
int disconnectFromDatabase(void);
void closeStatementHandles(void);
int registerVmHost(char *sysInfo, char *hostCapabilities, unsigned long hypervisorVersion, unsigned long libvirtVersion,
  char *osRelease, char *machineType);
int setVmHostOffline(void);
int sendMessageToClient(void);
int updateLifecycleState(char *machineName, char *lifecycleState, char *detail);
int validateVmState(const char *domainName, const char *stateText);
int updateVmState(const char *domainName, const char *stateText);
int updateVmInfo(void *vjsonParms);
int getMsgForVmHostMonitor(void);
int breakDqSession(void);
int getVmXMLDescription(int virtualMachineId, int xmlDescriptionLength);
int updateVmXMLDescription(char *machineName, char *xmlDescription);
int getOraErrorCode(void);

#endif /* ORADATALAYER_H_ */

/*
 * dataLayer.h
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#ifndef ORADATALAYER_H_
#define ORADATALAYER_H_

int connectToDatabase(void);
int disconnectFromDatabase(void);
void closeStatementHandles(void);
int registerVmHost(char *sysInfo, char *hostCapabilities, unsigned long hypervisorVersion, unsigned long libvirtVersion,
  char *osRelease, char *machineType);
int setVmHostOffline(void);

#endif /* ORADATALAYER_H_ */

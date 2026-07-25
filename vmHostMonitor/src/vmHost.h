/*
 * vmHosts.h
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#ifndef VMHOST_H_
#define VMHOST_H_

extern void *vmHostConnection;

int connectToVmHost(void);
void disconnectFromVmHost(void);
int monitorDomainEvents(void);
int setupEventLoop(void);
int virtualMachineIsRunning(char *machineName);
void *getVirtualDomain(char *machineName);
int vmHostErrorHandler(void);
int deleteStoragePool(void);

#endif /* VMHOST_H_ */

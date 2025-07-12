/*
 * vmHosts.h
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#ifndef VMHOSTS_H_
#define VMHOSTS_H_

int connectToVmHost(void);
void disconnectFromVmHost(void);
int monitorDomainEvents(void);
int setupEventLoop(void);
int virtualMachineIsRunning(char *machineName);

#endif /* VMHOSTS_H_ */

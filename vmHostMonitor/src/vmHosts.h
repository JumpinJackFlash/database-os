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

#endif /* VMHOSTS_H_ */

/*
 * virtualMachines.h
 *
 *  Created on: Jul 7, 2025
 *      Author: gilly
 */

#ifndef VIRTUALMACHINES_H_
#define VIRTUALMACHINES_H_

int createVirtualMachine(void);
int startVirtualMachine(void);
int stopVirtualMachine(void);
int undefineVirtualMachine(void);
int createCloudInitCdrom(void);

#endif /* VIRTUALMACHINES_H_ */

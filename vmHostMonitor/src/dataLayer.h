/*
 * dataLayer.h
 *
 *  Created on: May 8, 2025
 *      Author: gilly
 */

#ifndef DATALAYER_H_
#define DATALAYER_H_

int connectToDatabase(void);
int disconnectFromDatabase(void);
void closeStatementHandles(void);

#endif /* DATALAYER_H_ */

/*
 * errors.h
 *
 *  Created on: Jul 24, 2025
 *      Author: gilly
 */

#ifndef ERRORS_H_
#define ERRORS_H_

int jsonError(char *text);
int osErrorHandler(int rc);
char *getErrorText(int rc);

#endif /* ERRORS_H_ */

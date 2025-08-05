/*
 * vmHosMonitorDefs.h
 *
 *  Created on: Jul 24, 2025
 *      Author: gilly
 */

#ifndef VMHOSTMONITORDEFS_H_
#define VMHOSTMONITORDEFS_H_

#define GIT_TAG                                 "rc2025.09"
#define GIT_BRANCH                              "main"

#define CONFIG_FILE                             "vmHostMonitor.config"
#define PROGRAM_NAME                            "vmHostMonitor"

#define WORK_LENGTH                             1024

#define DIRECTORY_SEPARATOR                     '/'

#define HOME_ENVAR                              "ASTERION"
#define RUNTIME_USER_ENVAR                      "RUNTIME_USER"
#define RUNTIME_PASSWORD_ENVAR                  "RUNTIME_PASSWORD"
#define DATABASE_NAME_ENVAR                     "DATABASE_NAME"
#define ORACLE_HOME_ENVAR                       "ORACLE_HOME"
#define MAX_PID_SIZE                            32

#define PROC_PID_ALENGTH                        19              // /proc/4194304/stat  -- see /proc/sys/kernel/pid_max
#define PID_ALENGTH                             8
#define PID_FILE_PREFIX                         "/run/asterion"

#define HEARTBEAT_INTERVAL                      60
#define WAKE_UP_EARLY_PERCENT                   .1
#define USEC_TO_SEC_FACTOR                      .000001

#define OCI_ERROR_ORA_NOOBJ                     4043
#define OCI_ERROR_NO_TABVIEW                    942
#define OCI_INVALID_ORA_OBJ                     24372
#define OCI_EOF_COM_CHAN                        3113
#define OCI_NOT_CONNECTED                       3114
#define OCI_LOST_CONTACT                        3115
#define OCI_USER_REQUESTED_CANCEL               1013
#define OCI_TNS_BREAK                           12152

#define OCI_ILLEGAL_PARM_VALUE                  24801                     // This is the stupid return code for terminating stream reads...
#define OCI_QUEUE_TIMEOUT                       25228
#define OCI_ORPHANED_QUEUE                      25306
#define OCI_ARRAY_DQ_FAIL                       25326

#define CLIENT_HANDLE_LENGTH                    25
#define ORA_ERROR_TEXT_LENGTH                   513

#define OCI_CANCEL_OPERATION_TEXT               "ORA-01013: user requested cancel of current operation"

#define DB_NAME_LENGTH                          129                 // Tied to the database username column size, plus a null byte.

#define E_SUCCESS                               0
#define E_OCI_ERROR                             1
#define E_OSERR                                 2
#define E_FATAL_SERVER_ERROR                    3
#define E_LOG_FILE_DIRECTORY                    5
#define E_MEMORY_COUNT                          9
#define E_LOG_FILE                              10
#define E_ENVVAR                                11
#define E_CONFIG_FILE                           14
#define E_CONFIG_OPTION_VALUE                   20
#define E_CONFIG_OPTION                         21
#define E_BUFFER_OVERFLOW                       23
#define E_EOF                                   24
#define E_MALLOC                                34
#define E_RETURN_TYPE                           35
#define E_NO_DATA                               42
#define E_CHILD_DIED                            46
#define E_FATAL_QUEUE_ERROR                     68
#define E_CREATE_PID_FILE                       69
#define E_LIBVIRT_ERROR                         73
#define E_PLUGIN_ERROR                          514
#define E_JSON_ERROR                            520
#define E_STOP_QUEUE_THREAD                     533

#define TRUE                                    1
#define FALSE                                   0

#define WORK_LEN                                129

#define MSGT_STOP_QUEUE_THREAD                  15
#define MSGT_CREATE_VM                          20
#define MSGT_STOP_VM                            25
#define MSGT_UNDEFINE_VM                        30
#define MSGT_CREATE_CLOUD_INIT_CDROM            35
#define MSGT_DELETE_STORAGE_POOL                40
#define MSGT_START_VM                           45

#define LOG_OUTPUT_ALWAYS                       0
#define LOG_OUTPUT_ERROR                        1
#define LOG_OUTPUT_WARN                         2
#define LOG_OUTPUT_INFO                         3
#define LOG_OUTPUT_VERBOSE                      4
#define LOG_OUTPUT_IO                           5

#define LOGMSG_LENGTH                           2048


#define MACHINE_NAME_LENGTH                     31
#define VDISK_FILENAME_LENGTH                   256
#define OS_VARIANT_LENGTH                       31
#define NETWORK_SOURCE_LENGTH                   31
#define NETWORK_DEVICE_LENGTH                   31
#define VDISK_OPTIONS_LENGTH                    128

#define VIRT_INSTALL                            "virt-install"
#define VIRT_SHELL                              "virsh"

#endif /* VMHOSTMONITORDEFS_H_ */

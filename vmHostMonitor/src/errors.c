#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>

#include "vmHostMonitorDefs.h"
#include "logger.h"

static char workArea[WORK_LEN];

int jsonError(char *text)
{
  snprintf(workArea, sizeof(workArea)-1, "JSON item not found: %s", text);
  workArea[sizeof(workArea)-1] = '\0';
  logOutput(LOG_OUTPUT_ERROR, workArea);
  return E_JSON_ERROR;
}

int osErrorHandler(int rc)
{
  logOutput(LOG_OUTPUT_ERROR, strerror(errno));
  return rc;
}

char *getErrorText(int rc)
{
  switch (rc)
  {
    case E_OCI_ERROR:
      return("An Oracle Call Interface layer error was detected.");

    case E_OSERR:
      return "An operating system error was encountered.";

    case E_FATAL_SERVER_ERROR:
      return "A fatal error was detected by the server.";

    case E_ENVVAR:
      return "Environment variable not set";

    case E_LOG_FILE_DIRECTORY:
      return "Unable to create a directory for the log file.";

    case E_LOG_FILE:
      return "Unable to create a log file.";

    case E_BUFFER_OVERFLOW:
      return "An internal buffer overflow was detected.";

    case E_NO_DATA:
      return("No data returned from SQL statement.");

    case E_CONFIG_FILE:
      return "Configuration file not found.";

    case E_CONFIG_OPTION_VALUE:
      return "An invalid configuration option value was detected.";

    case E_CONFIG_OPTION:
      return "An invalid configuration option was detected.";

    case E_EOF:
      return "End of file encountered.";

    case E_MALLOC:
      return "Unable to allocate dynamic memory.";

    case E_RETURN_TYPE:
      return "Invalid return variable type.";

    case E_MEMORY_COUNT:
      return("Memory allocation/deallocation mismatch or memory over-allocation detected.");

    case E_CHILD_DIED:
      return "A child/spawned process has died or crashed.";

    case E_FATAL_QUEUE_ERROR:
      return("A fatal error was encountered when interacting with a database queue.  Try dropping and re-creating the queue.");

    case E_CREATE_PID_FILE:
      return("Unable to create PID file.  Is the program already running?");

    default:
      snprintf(workArea, sizeof(workArea)-1, "Error message for error code %d not found.", rc);
      workArea[sizeof(workArea)-1] = '\0';
      return workArea;
  }
}

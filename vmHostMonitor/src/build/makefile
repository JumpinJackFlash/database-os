################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include subdir.mk
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

OPTIONAL_TOOL_DEPS := \
$(wildcard ../makefile.defs) \
$(wildcard ../makefile.init) \
$(wildcard ../makefile.targets) \


BUILD_ARTIFACT_NAME := vmHostMonitor
BUILD_ARTIFACT_EXTENSION :=
BUILD_ARTIFACT_PREFIX :=
BUILD_ARTIFACT := $(BUILD_ARTIFACT_PREFIX)$(BUILD_ARTIFACT_NAME)$(if $(BUILD_ARTIFACT_EXTENSION),.$(BUILD_ARTIFACT_EXTENSION),)

# Add inputs and outputs from these tool invocations to the build variables 

# All Target
all: main-build

# Main-build Target
main-build: vmHostMonitor

# Tool invocations
vmHostMonitor: $(OBJS) $(USER_OBJS) makefile $(OPTIONAL_TOOL_DEPS)
	@echo 'Building target: $@'
	@echo 'Invoking: GCC C Linker'
	gcc -L"$(GIT_HOME)/common/dbCommon/build" -L"$(GIT_HOME)/common/oraCommon/Debug" -L"$(ORACLE_HOME)/lib" -pthread -o "vmHostMonitor" $(OBJS) $(USER_OBJS) $(LIBS) -lclntsh -locci -lsystemd -lvirt -lcjson
	@echo 'Finished building target: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) vmHostMonitor
	-@echo ' '

.PHONY: all clean dependents main-build

-include ../makefile.targets

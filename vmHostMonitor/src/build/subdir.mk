################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../dbQueueMonitor.c \
../errors.c \
../logger.c \
../memory.c \
../oraDataLayer.c \
../utils.c \
../virtualMachines.c \
../vmHostMonitor.c \
../vmHosts.c 

C_DEPS += \
./dbQueueMonitor.d \
./errors.d \
./logger.d \
./memory.d \
./oraDataLayer.d \
./utils.d \
./virtualMachines.d \
./vmHostMonitor.d \
./vmHosts.d 

OBJS += \
./dbQueueMonitor.o \
./errors.o \
./logger.o \
./memory.o \
./oraDataLayer.o \
./utils.o \
./virtualMachines.o \
./vmHostMonitor.o \
./vmHosts.o 


# Each subdirectory must supply rules for building sources it contributes
%.o: ../%.c subdir.mk
	@echo 'Building file: $<'
	@echo 'Invoking: GCC C Compiler'
	gcc -DLINUX -I"$(ORACLE_HOME)/rdbms/public" -I"$(GIT_HOME)/common/dbCommon" -I"$(GIT_HOME)/common/oraCommon" -O0 -g3 -Wall -c -fmessage-length=0 -Wformat-truncation=0 -pthread -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


clean: clean--2e-

clean--2e-:
	-$(RM) ./dbQueueMonitor.d ./dbQueueMonitor.o ./errors.d ./errors.o ./logger.d ./logger.o ./memory.d ./memory.o ./oraDataLayer.d ./oraDataLayer.o ./utils.d ./utils.o ./virtualMachines.d ./virtualMachines.o ./vmHostMonitor.d ./vmHostMonitor.o ./vmHosts.d ./vmHosts.o

.PHONY: clean--2e-


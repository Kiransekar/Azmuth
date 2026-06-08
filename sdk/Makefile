# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Makefile for Azmuth SDK (libxcew)
# Software audit §S4.2

PREFIX     ?= riscv64-unknown-elf-
CC          = $(PREFIX)gcc
AR          = $(PREFIX)ar
OBJCOPY     = $(PREFIX)objcopy

CFLAGS     = -march=rv32i -mabi=ilp32 -mcmodel=medlow -fno-pic \
             -Os -Wall -Wextra -Werror \
             -Iinclude -nostdlib -ffreestanding

SRCS       = src/xcew_eml.c src/xcew_snn.c src/xcew_sys.c
OBJS       = $(SRCS:.c=.o)
LIB        = lib/libxcew.a

.PHONY: all clean

all: $(LIB)

$(LIB): $(OBJS)
	@mkdir -p lib
	$(AR) rcs $@ $^
	@echo "Built $@"

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(LIB)
	rm -rf lib/

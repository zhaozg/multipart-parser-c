# Makefile for Lua binding of multipart-parser-c

# Detect LuaJIT or Lua
LUAJIT_CFLAGS := $(shell pkg-config --cflags luajit 2>/dev/null)
LUAJIT_LIBS := $(shell pkg-config --libs luajit 2>/dev/null)

ifneq ($(LUAJIT_CFLAGS),)
    LUA_CFLAGS = $(LUAJIT_CFLAGS)
    LUA_LIBS = $(LUAJIT_LIBS)
    LUA_INCDIR := $(shell pkg-config --variable=includedir luajit)
    LUA_LIBDIR := $(shell pkg-config --variable=libdir luajit)
    LUA_CMODDIR := $(shell pkg-config --variable=INSTALL_CMOD luajit 2>/dev/null || echo "/usr/local/lib/lua/5.1")
else
    LUA_CFLAGS := $(shell pkg-config --cflags lua5.1 2>/dev/null || pkg-config --cflags lua 2>/dev/null)
    LUA_LIBS := $(shell pkg-config --libs lua5.1 2>/dev/null || pkg-config --libs lua 2>/dev/null)
    LUA_INCDIR := $(shell pkg-config --variable=includedir lua5.1 2>/dev/null || pkg-config --variable=includedir lua 2>/dev/null)
    LUA_LIBDIR := $(shell pkg-config --variable=libdir lua5.1 2>/dev/null || pkg-config --variable=libdir lua 2>/dev/null)
    LUA_CMODDIR := $(shell pkg-config --variable=INSTALL_CMOD lua5.1 2>/dev/null || echo "/usr/local/lib/lua/5.1")
endif

# Compiler flags
CC ?= gcc
CFLAGS = -O2 -Wall -fPIC $(LUA_CFLAGS) -I../..
LDFLAGS = -shared
LIBS = $(LUA_LIBS)

# Source files
SRCS = multipart.c ../../multipart_parser.c
TARGET = multipart_parser.so

# Build target
all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

# Install target
install: $(TARGET)
	install -d $(LUA_CMODDIR)
	install -m 0755 $(TARGET) $(LUA_CMODDIR)/

# Clean target
clean:
	rm -f $(TARGET) *.o

# Test target
test: $(TARGET)
	@echo "=========================================="
	@echo "Running Multipart Parser Lua Tests"
	@echo "=========================================="
	@cd tests && luajit run_all_tests.lua || lua run_all_tests.lua

# Run individual test suites
test-core: $(TARGET)
	@cd tests && (luajit test_core.lua || lua test_core.lua)

test-h1-h2: $(TARGET)
	@cd tests && (luajit test_h1_h2_memory_errors.lua || lua test_h1_h2_memory_errors.lua)

test-m1-m2: $(TARGET)
	@cd tests && (luajit test_m1_m2_limits_stats.lua || lua test_m1_m2_limits_stats.lua)

test-m3: $(TARGET)
	@cd tests && (luajit test_m3_simple_parse.lua || lua test_m3_simple_parse.lua)

test-m4: $(TARGET)
	@cd tests && (luajit test_m4_streaming.lua || lua test_m4_streaming.lua)

test-large: $(TARGET)
	@cd tests && (luajit test_large_data.lua || lua test_large_data.lua)

# Run examples
example-basic: $(TARGET)
	@cd examples && luajit basic_usage.lua

example-streaming: $(TARGET)
	@cd examples && luajit streaming_usage.lua

.PHONY: all install clean test test-core test-h1-h2 test-m1-m2 test-m3 test-m4 test-large example-basic example-streaming

# Makefile for modular test suite
# Builds individual test modules and combines them into a single test executable

CC?=cc
CFLAGS?=-std=c89 -ansi -pedantic -O3 -Wall -fPIC
PARENT_DIR=..

# Source files
TEST_SOURCES = test_basic.c test_binary.c test_rfc.c test_errors.c \
               test_advanced.c test_reset.c test_safety.c test_main.c

# Object files
TEST_OBJECTS = $(TEST_SOURCES:.c=.o)

# Parser source
PARSER_SRC = $(PARENT_DIR)/multipart_parser.c
PARSER_OBJ = multipart_parser.o

# Default target
all: test_suite

# Compile parser
$(PARSER_OBJ): $(PARSER_SRC)
	$(CC) $(CFLAGS) -c $(PARSER_SRC) -o $(PARSER_OBJ)

# Compile test modules
%.o: %.c test_common.h
	$(CC) $(CFLAGS) -I$(PARENT_DIR) -c $< -o $@

# Link test suite
test_suite: $(TEST_OBJECTS) $(PARSER_OBJ)
	$(CC) $(CFLAGS) -o test_suite $(TEST_OBJECTS) $(PARSER_OBJ)

# Run tests
test: test_suite
	@echo "Running comprehensive test suite..."
	./test_suite

# Clean build artifacts
clean:
	rm -f $(TEST_OBJECTS) $(PARSER_OBJ) test_suite

.PHONY: all test clean

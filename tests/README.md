# Modular Test Suite

This directory contains the reorganized, modular test suite for the multipart parser. The original monolithic `test.c` (1909 lines) has been split into focused, maintainable modules.

## Structure

```
tests/
├── test_common.h       # Shared macros, helpers, and test declarations
├── test_main.c         # Main test runner (coordinates all tests)
├── test_basic.c        # Basic parser functionality (7 tests)
├── test_binary.c       # Binary data edge cases (6 tests)
├── test_rfc.c          # RFC 2046 & 7578 compliance (8 tests)
├── test_errors.c       # Error handling & regressions (4 tests)
├── test_advanced.c     # Advanced features (5 tests)
├── test_reset.c        # Parser reset functionality (5 tests)
├── test_safety.c       # Safety & robustness (2 tests)
├── Makefile            # Build system for modular tests
└── README.md           # This file
```

## Building and Running

### Run All Tests (Recommended)

From the repository root:
```bash
make test_modular
```

Or from the tests directory:
```bash
cd tests
make test
```

### Build Only
```bash
cd tests
make
```

This creates the `test_suite` executable.

### Run Tests Directly
```bash
cd tests
./test_suite
```

## Test Coverage

**Total: 37 comprehensive tests**

- **Section 1** (test_basic.c): Basic parser functionality
  - Parser initialization and cleanup
  - Memory allocation checks
  - Basic parsing
  - Chunked parsing (1 byte at a time)
  - Large boundary strings
  - Boundary format validation
  - User data get/set

- **Section 2** (test_binary.c): Binary data handling
  - Binary data with embedded CR
  - Binary data with NULL bytes
  - Binary data with boundary-like sequences
  - Binary data with high bytes (0x80-0xFF)
  - Binary data with all zeros
  - Binary data with multiple CRLF sequences

- **Section 3 & 9** (test_rfc.c): RFC compliance
  - RFC 2046 single part
  - RFC 2046 multiple parts
  - RFC 2046 with preamble
  - RFC 2046 empty part
  - RFC 7578 multiple files with same name
  - RFC 7578 UTF-8 content
  - RFC 7578 special field names
  - RFC 7578 empty filename

- **Section 4 & 5** (test_errors.c): Error handling
  - Issue #13 regression (header value CR with 1-byte feeding)
  - Invalid header field character
  - Invalid boundary format
  - Callback pause

- **Section 6 & 7** (test_advanced.c): Advanced features
  - Multiple headers in one part
  - Empty part data
  - Very long header values
  - Clean end after final boundary
  - Callback buffering

- **Section 8** (test_reset.c): Parser reset
  - Basic reset with new boundary
  - Reset keeping same boundary
  - Reset with boundary too long
  - Reset with NULL parser pointer
  - Reset clears error state

- **Section 10** (test_safety.c): Safety and robustness
  - NULL pointer safety in API functions
  - NULL buffer safety with valid parser

## Advantages of Modular Structure

1. **Maintainability**: Easy to locate and modify specific test categories
2. **Clarity**: Each file has a focused purpose (200-500 lines each)
3. **Extensibility**: Simple to add new test categories
4. **Modularity**: Tests are organized by functionality
5. **Documentation**: Clear structure documents test organization

## Running Tests

All test commands now use the modular test suite:

```bash
# Run all tests
make test

# Or run directly from tests directory
cd tests
make test
```

The modular test suite is the standard way to test the library.

## Adding New Tests

To add a new test:

1. Identify the appropriate test file (or create a new one)
2. Add the test function implementation
3. Declare the function in `test_common.h`
4. Add the test call in `test_main.c`
5. Update this README if adding a new category

Example:
```c
/* In test_basic.c */
void test_my_new_feature(void) {
    TEST_START("My new feature");
    /* test implementation */
    TEST_PASS();
}

/* In test_common.h */
void test_my_new_feature(void);

/* In test_main.c main() */
test_my_new_feature();
```

## Cleaning

```bash
# From repository root
make clean

# From tests directory
make clean
```

This removes all compiled objects and executables.

## Requirements

- C89/ANSI C compiler (GCC or Clang)
- Standard C library
- Make

## Notes

- All tests use C89 standard for maximum compatibility
- Tests are pedantic and compile with `-Wall`
- No external dependencies beyond standard C library
- Test counters are global (defined in test_main.c)
- All tests return 0 on success, non-zero on failure

# Testing Guide

## Running Tests

### Complete Test Suite

Run all tests (basic + binary edge cases):
```bash
make test
```

This runs:
1. **test_basic.c** - Basic functionality tests (7 tests)
2. **test_binary.c** - Binary data edge case tests (6 tests)

### Basic Test Suite

The basic test suite (`test_basic.c`) includes:
- Parser initialization and cleanup
- Malloc failure handling verification
- Basic multipart data parsing
- Chunked parsing (1 byte at a time)
- Large boundary strings
- Invalid boundary detection
- User data get/set functionality

Expected output:
```
=== Multipart Parser Basic Test Suite ===

Test 1: Parser initialization and cleanup ... PASSED
Test 2: Malloc result check exists ... PASSED
Test 3: Basic parsing of multipart data ... PASSED
Test 4: Chunked parsing (1 byte at a time) ... PASSED
Test 5: Parser with large boundary string ... PASSED
Test 6: Invalid boundary detection ... PASSED
Test 7: User data get/set ... PASSED

=== Test Summary ===
Total: 7
Passed: 7
Failed: 0
```

### Binary Data Edge Case Tests

The binary test suite (`test_binary.c`) includes:
- Binary data with embedded CR characters (documents Issue #33)
- Binary data with NULL bytes
- Binary data containing boundary-like sequences
- Binary data with high bytes (0x80-0xFF)
- All-zero binary data
- Binary data with multiple CRLF sequences

Expected output:
```
=== Binary Data Edge Case Tests ===

Test 1: Binary data with embedded CR (Issue #33) ... KNOWN ISSUE (Issue #33)
Test 2: Binary data with NULL bytes ... PASSED
Test 3: Binary data containing boundary-like sequences ... PASSED
Test 4: Binary data with high bytes (0x80-0xFF) ... PASSED
Test 5: Binary data with all zero bytes ... PASSED
Test 6: Binary data with multiple CRLF sequences ... PASSED

=== Test Summary ===
Total: 6
Passed: 6
Failed: 0
```

Note: Test 1 documents Issue #33 (known limitation with CR in binary data).

### Performance Benchmarks

Run performance benchmarks:
```bash
make benchmark
```

This runs `test_performance.c` which measures:
1. **Small message throughput** - Processing many small messages
2. **Large message parsing** - Single large message (100KB)
3. **Chunked parsing efficiency** - Various chunk sizes (1-256 bytes)
4. **Multiple parts performance** - Messages with 1-50 parts

Sample output:
```
=== Multipart Parser Performance Benchmarks ===

=== Benchmark 1: Small Messages ===
Iterations: 10000
Time: 0.002 seconds
Messages/sec: 5252101
Throughput: 230.40 MB/s

=== Benchmark 2: Large Message (100KB content) ===
Message size: 102441 bytes
Parse time: 0.000254 seconds
Throughput: 384.63 MB/s

=== Benchmark 3: Chunked Parsing Efficiency ===
Chunk size:    1 bytes - Time: 0.003 sec - Rate: 1587806 parses/sec
Chunk size:    4 bytes - Time: 0.002 sec - Rate: 2844141 parses/sec
Chunk size:   16 bytes - Time: 0.001 sec - Rate: 3467406 parses/sec
Chunk size:   64 bytes - Time: 0.001 sec - Rate: 3657644 parses/sec
Chunk size:  256 bytes - Time: 0.001 sec - Rate: 3813883 parses/sec

=== Benchmark 4: Multiple Parts Performance ===
Parts:  1 - Size:    57 bytes - Time: 0.000 sec - Rate: 4424779 parses/sec
Parts:  5 - Size:   301 bytes - Time: 0.001 sec - Rate: 919963 parses/sec
Parts: 10 - Size:   606 bytes - Time: 0.002 sec - Rate: 460829 parses/sec
Parts: 20 - Size:  1216 bytes - Time: 0.004 sec - Rate: 234192 parses/sec
Parts: 50 - Size:  3046 bytes - Time: 0.011 sec - Rate: 94171 parses/sec
```

**Note**: Results vary based on system performance and load. These provide a baseline for comparison.

### Building the Library

Build the object file:
```bash
make
```

Build as a shared library:
```bash
make solib
```

### Clean Build Artifacts

```bash
make clean
```

## Test Coverage

### Positive Tests
- ✅ Valid multipart data parsing
- ✅ Multiple callback invocations
- ✅ Chunked input processing (1 byte, variable sizes)
- ✅ Binary data with NULL bytes
- ✅ Binary data with high bytes (0x80-0xFF)
- ✅ All-zero binary data

### Negative Tests
- ✅ Invalid boundary detection
- ✅ Malformed data rejection

### Boundary Tests
- ✅ Large boundary strings (255 characters)
- ✅ Small boundary strings
- ✅ Boundary-like sequences in data

### Binary Data Edge Cases
- ✅ NULL bytes in binary data
- ✅ High bytes (0x80-0xFF)
- ✅ All-zero data
- ✅ Multiple CRLF sequences
- ⚠️ CR in binary data (Issue #33 - documented limitation)

### Security Tests
- ✅ NULL pointer handling
- ✅ Memory allocation failure paths
- ✅ Buffer boundary conditions

### Integration Tests
- ✅ User data context management
- ✅ Callback sequencing

### Performance Tests
- ✅ Small message throughput baseline
- ✅ Large message parsing baseline
- ✅ Chunked parsing efficiency (1-256 byte chunks)
- ✅ Multiple parts scalability (1-50 parts)

### Security Tests
- ✅ NULL pointer handling
- ✅ Memory allocation failure paths
- ✅ Buffer boundary conditions

### Integration Tests
- ✅ User data context management
- ✅ Callback sequencing

## Known Limitations in Tests

Due to RFC compliance issues (see `SECURITY_IMPROVEMENTS.md`), the following are NOT currently tested:

- ❌ Complete multipart message parsing with proper end callbacks
- ❌ Multiple parts in a single message with proper boundaries
- ❌ RFC 2046 compliant boundary format

These limitations are documented in:
- `SECURITY_IMPROVEMENTS.md`: Full analysis
- `docs/ISSUES_TRACKING.md`: Issue #20, #28, #33

## Adding New Tests

When adding new tests to `test_basic.c`:

1. Follow the existing pattern:
   ```c
   void test_my_feature(void) {
       TEST_START("Description of test");

       // Your test code

       if (success) {
           TEST_PASS();
       } else {
           TEST_FAIL("Reason for failure");
       }
   }
   ```

2. Call your test from `main()`:
   ```c
   int main(void) {
       // ... existing tests ...
       test_my_feature();
       // ... rest of main ...
   }
   ```

3. Ensure C89 compliance:
   - Declare all variables at the start of blocks
   - Don't use C99 features (for loop declarations, etc.)
   - Use `%zu` printf format only when necessary (may warn)

4. Run the tests:
   ```bash
   make clean && make test
   ```

## Continuous Integration

The test suite is designed to be used in CI/CD pipelines:

```bash
#!/bin/bash
set -e  # Exit on error

make clean
make test

if [ $? -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Tests failed!"
    exit 1
fi
```

## Security Testing

### CodeQL

The codebase has been scanned with CodeQL:
```
Analysis Result: 0 vulnerabilities
Status: ✅ PASSED
```

### Memory Leak Detection

Run with Valgrind (if available):
```bash
make test_basic
valgrind --leak-check=full ./test_basic
```

Expected: No memory leaks, all allocations freed.

## Performance Testing

For performance benchmarking, you can create additional tests:

```c
#include <time.h>

void test_performance(void) {
    clock_t start, end;
    double cpu_time_used;

    start = clock();
    // Perform many parse operations
    end = clock();

    cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
    printf("Time taken: %f seconds\n", cpu_time_used);
}
```

## Test Data

### Valid Multipart Format (Current Implementation)

```
boundary\r\n
Content-Type: text/plain\r\n
\r\n
data content
```

Note: This differs from RFC 2046 which requires `--boundary\r\n` prefix.

### Invalid Formats

The parser correctly rejects:
- Wrong boundary string
- Invalid header characters
- Malformed structure

## Troubleshooting

### Test Compilation Errors

If you get C89 compliance errors:
- Check for variable declarations after statements
- Check for C99 loop syntax (for (int i = 0; ...))
- Check for // comments (use /* */ instead)

### Test Failures

If tests fail:
1. Check if you modified the parser code
2. Review `SECURITY_IMPROVEMENTS.md` for known limitations
3. Ensure test data matches the expected format
4. Run with DEBUG_MULTIPART defined to see state transitions:
   ```bash
   gcc -DDEBUG_MULTIPART -o test_basic test_basic.c multipart_parser.c
   ./test_basic 2>&1 | less
   ```

## Contributing Tests

When contributing new tests:
1. Document what the test covers
2. Include both positive and negative cases
3. Follow C89 standard
4. Add to this documentation
5. Ensure all tests pass before submitting

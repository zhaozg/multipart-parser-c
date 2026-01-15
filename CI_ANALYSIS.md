# CI/CD and Code Analysis

This document describes the continuous integration, testing, and analysis infrastructure for multipart-parser-c.

## Overview

The project includes comprehensive CI/CD pipelines and local analysis tools to ensure code quality, memory safety, and performance:

- **Automated Testing**: Unit tests, regression tests, RFC compliance tests
- **Memory Safety**: AddressSanitizer, UndefinedBehaviorSanitizer, Valgrind
- **Code Coverage**: Line and branch coverage analysis
- **Performance Profiling**: Callgrind and Cachegrind profiling
- **Security Scanning**: CodeQL static analysis

## GitHub Actions Workflows

### CI Pipeline (`.github/workflows/ci.yml`)

Runs automatically on:
- Push to main/master branches
- Pull requests to main/master
- Manual trigger via workflow_dispatch

**Jobs**:

1. **Build and Test**
   - Builds library and all tests
   - Runs complete test suite
   - Runs performance benchmarks

2. **AddressSanitizer**
   - Detects memory leaks
   - Detects buffer overflows
   - Detects use-after-free errors
   - Detects initialization order bugs

3. **UndefinedBehaviorSanitizer**
   - Detects undefined behavior
   - Detects integer overflows
   - Detects null pointer dereferences
   - Detects misaligned access

4. **Valgrind Memcheck**
   - Memory leak detection
   - Invalid memory access detection
   - Uninitialized memory usage detection
   - Generates detailed reports

5. **Code Coverage**
   - Line coverage analysis
   - Branch coverage analysis
   - HTML reports generated
   - Coverage percentage calculated

6. **Performance Profiling (Callgrind)**
   - Identifies performance hotspots
   - Function call counts
   - Instruction counts
   - Generates optimization recommendations

7. **Cache Profiling (Cachegrind)**
   - Cache hit/miss analysis
   - Memory access patterns
   - Cache efficiency metrics

### Upstream Tracking (`.github/workflows/upstream-tracking.yml`)

Runs weekly (Mondays at 9 AM UTC) to:
- Check for new upstream issues
- Check for new upstream PRs
- Generate tracking reports
- Create/update tracking issues

## Local Development

### Running Tests Locally

**Basic test suite**:
```bash
make clean
make test
```

**With AddressSanitizer**:
```bash
make test-asan
```

**With UndefinedBehaviorSanitizer**:
```bash
make test-ubsan
```

**With Valgrind**:
```bash
make test-valgrind
```

**All sanitizers and tests**:
```bash
make test-all
```

### Code Coverage

Generate code coverage report:
```bash
make coverage
```

This will:
1. Build tests with coverage instrumentation
2. Run all tests
3. Generate coverage data
4. Create HTML report in `coverage-html/`
5. Display text summary in terminal

View HTML report:
```bash
# Linux/macOS
xdg-open coverage-html/index.html   # Linux
open coverage-html/index.html        # macOS

# Or just open the file in your browser
```

Coverage files generated:
- `coverage.txt` - Text summary
- `coverage.xml` - XML format (for CI tools)
- `coverage.info` - LCOV format
- `coverage-html/` - Browsable HTML report
- `*.gcov` - Individual file coverage

### Performance Profiling

**Callgrind profiling** (find hotspots):
```bash
make profile-callgrind
```

This generates:
- `callgrind.out` - Raw profiling data
- `callgrind-report.txt` - Annotated report
- Terminal output showing top functions

View with KCachegrind (GUI):
```bash
kcachegrind callgrind.out
```

**Cachegrind profiling** (cache analysis):
```bash
make profile-cachegrind
```

This generates:
- `cachegrind.out` - Raw cache data
- `cachegrind-report.txt` - Cache statistics
- Terminal output showing cache performance

### Interpreting Results

#### AddressSanitizer Output

**Success** (no issues):
```
=================================================================
All tests passed with AddressSanitizer enabled.
=================================================================
```

**Failure** (example):
```
=================================================================
==12345==ERROR: AddressSanitizer: heap-buffer-overflow
READ of size 4 at 0x... thread T0
    #0 0x... in multipart_parser_execute
    #1 0x... in test_basic
...
```

Action: Fix the buffer overflow by checking bounds properly.

#### Valgrind Output

**Success**:
```
==12345== HEAP SUMMARY:
==12345==     in use at exit: 0 bytes in 0 blocks
==12345==   total heap usage: 10 allocs, 10 frees, 1,024 bytes allocated
==12345== 
==12345== All heap blocks were freed -- no leaks are possible
```

**Failure** (leak detected):
```
==12345== LEAK SUMMARY:
==12345==    definitely lost: 256 bytes in 1 blocks
==12345==    indirectly lost: 0 bytes in 0 blocks
```

Action: Check for missing `free()` calls.

#### Coverage Report

Target coverage: **>90%** for core parser logic

Example output:
```
------------------------------------------------------------------------------
GCC Code Coverage Report
Directory: .
------------------------------------------------------------------------------
File                           Lines    Exec  Cover   Missing
------------------------------------------------------------------------------
multipart_parser.c               378     365  96.6%   45-47,123
test_basic.c                     180     180 100.0%   
------------------------------------------------------------------------------
TOTAL                            558     545  97.7%
------------------------------------------------------------------------------
```

**Good coverage**: >95% on `multipart_parser.c`
**Acceptable**: 90-95% (some edge cases untested)
**Needs improvement**: <90%

#### Callgrind Hotspots

Example output:
```
--------------------------------------------------------------------------------
Ir                 
--------------------------------------------------------------------------------
12,453,678 (100.0%)  PROGRAM TOTALS

--------------------------------------------------------------------------------
Ir                  file:function
--------------------------------------------------------------------------------
6,227,456 (50.0%)   multipart_parser.c:multipart_parser_execute
2,490,982 (20.0%)   multipart_parser.c:process_boundary
  746,845 ( 6.0%)   test_performance.c:main
```

**Analysis**:
- `multipart_parser_execute` is the hotspot (50% of instructions)
- This is expected - it's the main parsing function
- Focus optimization on functions >5% if performance issues exist

## Requirements

### For Local Development

**Ubuntu/Debian**:
```bash
sudo apt-get install gcc make valgrind lcov gcovr kcachegrind
```

**macOS**:
```bash
brew install gcc make lcov gcovr
brew install valgrind  # Note: Valgrind support on macOS is limited
```

**Fedora/RHEL**:
```bash
sudo dnf install gcc make valgrind lcov kcachegrind
pip install gcovr
```

### Minimum Versions

- GCC: 7.0+ (for sanitizers)
- Valgrind: 3.13+
- lcov: 1.13+
- gcovr: 4.0+

## CI Artifacts

After CI runs, the following artifacts are available for download:

1. **valgrind-logs** (30 days retention)
   - Detailed Valgrind memcheck logs for each test
   - `valgrind-basic.log`, `valgrind-binary.log`, etc.

2. **coverage-reports** (30 days retention)
   - `coverage.info` - LCOV format
   - `coverage.txt` - Text summary
   - `coverage.xml` - XML format
   - `coverage-html/` - Browsable HTML reports
   - `*.gcov` - Individual file coverage

3. **profiling-data** (30 days retention)
   - `callgrind.out` - Raw Callgrind data
   - `callgrind-report.txt` - Annotated report
   - `callgrind-summary.txt` - Top functions summary
   - `hotspots.txt` - Identified hotspots

4. **cache-profiling-data** (30 days retention)
   - `cachegrind.out` - Raw Cachegrind data
   - `cachegrind-report.txt` - Cache analysis
   - `cachegrind-summary.txt` - Cache statistics

## Best Practices

### Before Committing

1. Run basic tests:
   ```bash
   make clean && make test
   ```

2. Check for memory issues (quick):
   ```bash
   make test-asan
   ```

3. Optional but recommended:
   ```bash
   make test-valgrind
   ```

### Before Releasing

1. Run full test suite:
   ```bash
   make test-all
   ```

2. Check code coverage:
   ```bash
   make coverage
   # Aim for >90% coverage
   ```

3. Profile if performance-critical:
   ```bash
   make profile-callgrind
   ```

4. Review all CI job results in GitHub Actions

### Performance Optimization Workflow

1. **Establish baseline**:
   ```bash
   make benchmark
   # Save output for comparison
   ```

2. **Profile to find hotspots**:
   ```bash
   make profile-callgrind
   # Identify top functions
   ```

3. **Optimize identified hotspots**

4. **Verify improvement**:
   ```bash
   make benchmark
   # Compare with baseline
   ```

5. **Ensure correctness**:
   ```bash
   make test-all
   # Verify no regressions
   ```

## Troubleshooting

### AddressSanitizer False Positives

If ASAN reports issues in system libraries, add suppressions to the build flags:
```makefile
ASAN_FLAGS += -fsanitize-blacklist=asan.blacklist
```

### Valgrind Suppressions

System library false positives are suppressed in `.valgrind.suppressions`.

To add new suppressions:
1. Run Valgrind and capture the error
2. Generate suppression with `--gen-suppressions=all`
3. Add to `.valgrind.suppressions`

### Coverage Not 100%

Some code paths may be hard to test:
- Error handling for rare system failures (malloc failure, etc.)
- Platform-specific code
- Debug-only code paths

This is acceptable if:
- Critical paths are covered (>95%)
- Untested code is documented
- Manual testing performed for edge cases

## Related Documentation

- [TESTING.md](TESTING.md) - Test suite documentation
- [SECURITY_IMPROVEMENTS.md](SECURITY_IMPROVEMENTS.md) - Security analysis
- [OPTIMIZATION_SUMMARY.md](OPTIMIZATION_SUMMARY.md) - Optimization work completed
- [CHANGELOG.md](CHANGELOG.md) - Version history

## Continuous Improvement

This CI/CD infrastructure enables:
- ✅ Catching bugs before they reach production
- ✅ Preventing regressions with regression tests
- ✅ Identifying performance bottlenecks early
- ✅ Maintaining high code quality standards
- ✅ Ensuring memory safety and correctness
- ✅ Data-driven optimization decisions

All checks run automatically on every push and PR, providing fast feedback to developers.

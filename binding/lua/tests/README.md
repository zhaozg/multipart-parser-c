# Multipart Parser Lua Binding Test Suite

This directory contains comprehensive tests for the Lua binding of multipart-parser-c.

## Test Organization

### Test Suites

1. **test_core.lua** - Core functionality tests (23 tests)
   - Basic parser creation and usage
   - Callback mechanisms
   - Simple parse function
   - Binary data handling
   - Error cases

2. **test_large_data.lua** - Large data handling tests
   - 4GB data simulation
   - Memory safety validation
   - Performance with large payloads

3. **test_h1_h2_memory_errors.lua** - Memory leak & error handling (8 tests)
   - H1: Memory leak fixes
   - H2: Enhanced error handling with `get_last_lua_error()`
   - Callback error capture

4. **test_m1_m2_limits_stats.lua** - Memory limits & statistics (8 tests)
   - M1: Configurable memory limits
   - M2: Parsing statistics (`get_stats()`)

5. **test_m3_simple_parse.lua** - Simple parse mode enhancements (8 tests)
   - M3: Progress callbacks in simple mode
   - Parsing interruption
   - Complete part information

6. **test_m4_streaming.lua** - Streaming support (8 tests)
   - M4: `feed()` method for streaming
   - Pause/resume functionality
   - Chunked data processing

## Running Tests

### Run All Tests
```bash
cd tests
luajit run_all_tests.lua
```

### Run Individual Test Suite
```bash
cd tests
luajit test_core.lua
luajit test_h1_h2_memory_errors.lua
# ... etc
```

### Run from Parent Directory
```bash
make test
```

## Test Statistics

- **Total Test Suites**: 6
- **Total Test Cases**: 55
- **Test Coverage**: 
  - Core functionality: ✓
  - Error handling: ✓
  - Memory management: ✓
  - Streaming: ✓
  - Statistics: ✓

## Adding New Tests

When adding new tests:

1. Create a new test file following the naming pattern `test_*.lua`
2. Use the standard test harness structure (see existing tests)
3. Add the new suite to `run_all_tests.lua`
4. Update this README
5. Ensure all tests pass before committing

## Test Harness Pattern

```lua
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function test_start(name)
  tests_run = tests_run + 1
  io.write(string.format("Test %d: %s ... ", tests_run, name))
  io.flush()
end

local function test_pass()
  io.write("PASSED\n")
  tests_passed = tests_passed + 1
end

local function test_fail(msg)
  io.write(string.format("FAILED: %s\n", msg))
  tests_failed = tests_failed + 1
end

-- ... test functions ...

-- Print summary and exit
print(string.format("Tests run: %d", tests_run))
print(string.format("Tests passed: %d", tests_passed))
print(string.format("Tests failed: %d", tests_failed))

if tests_failed > 0 then
  os.exit(1)
else
  os.exit(0)
end
```

## Requirements

- LuaJIT 2.0+ or Lua 5.1+
- Built multipart_parser.so module in parent directory

## Continuous Integration

These tests are run automatically in CI/CD pipelines to ensure code quality and prevent regressions.

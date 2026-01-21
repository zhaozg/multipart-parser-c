# Multipart Parser Lua Binding Test Suite

This directory contains comprehensive tests for the Lua binding of multipart-parser-c.

## Test Organization

### Test Suites

1. **test_core.lua** - Core parsing & error handling tests (27 tests)
   - Module loading and version
   - Parser initialization
   - Basic parsing with callbacks
   - Multi-part parsing
   - Binary data handling
   - Callback mechanisms (pause/resume)
   - Header accumulation
   - UTF-8 data
   - Simple parse function
   - Error handling (callback errors, error state)

2. **test_memory.lua** - Memory limits & state management tests (8 tests)
   - Memory limit parameters
   - Memory limit enforcement
   - Memory tracking
   - Parser reset with new boundary
   - Parser reset keeping same boundary
   - Parser reset clearing error state
   - Streaming with memory limits
   - Memory leak verification

3. **test_streaming.lua** - Streaming & progress callback tests (14 tests)
   - Progress callbacks
   - Progress parameters
   - Interrupt parsing
   - Multiple parts progress tracking
   - Feed method
   - Chunked feeding
   - Pause/resume functionality
   - Incremental parsing
   - Streaming error handling

4. **test_large_data.lua** - Large data handling tests
   - 4GB data simulation
   - Memory safety validation
   - Performance with large payloads

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
luajit test_memory.lua
luajit test_streaming.lua
luajit test_large_data.lua
```

### Run from Parent Directory
```bash
make test
```

## Test Statistics

- **Total Test Suites**: 4
- **Test Coverage**: 
  - Core functionality: ✓
  - Memory management: ✓
  - Streaming: ✓
  - Large data handling: ✓

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

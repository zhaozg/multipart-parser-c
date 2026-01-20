# Lua Binding Test & Example Organization

## Directory Structure

```
binding/lua/
├── multipart.c              # C binding implementation
├── Makefile                 # Build and test orchestration
├── README.md                # Main binding documentation
├── tests/                   # Test suite directory
│   ├── README.md            # Test documentation
│   ├── run_all_tests.lua    # Unified test runner
│   ├── test_core.lua        # Core functionality (23 tests)
│   ├── test_large_data.lua  # Large data handling
│   ├── test_h1_h2_memory_errors.lua  # H1/H2 tasks (8 tests)
│   ├── test_m1_m2_limits_stats.lua   # M1/M2 tasks (8 tests)
│   ├── test_m3_simple_parse.lua      # M3 task (8 tests)
│   └── test_m4_streaming.lua         # M4 task (8 tests)
└── examples/                # Example code directory
    ├── README.md            # Examples documentation
    ├── basic_usage.lua      # Basic usage patterns
    └── streaming_usage.lua  # Advanced streaming examples
```

## Test Organization

### Naming Convention
- `test_*.lua` - Test suites
- `test_<feature>.lua` - Feature-specific tests
- `test_<task_id>_<description>.lua` - Task-specific tests (e.g., test_h1_h2_memory_errors.lua)

### Test Categories

1. **Core Functionality** (test_core.lua)
   - 23 tests covering basic operations
   - Parser creation, callbacks, simple parse
   - Binary data, error handling

2. **Task-Specific Tests**
   - H1/H2: Memory & errors (8 tests)
   - M1/M2: Limits & statistics (8 tests)
   - M3: Simple parse enhancements (8 tests)
   - M4: Streaming support (8 tests)

3. **Performance Tests**
   - Large data handling (4GB simulation)

### Total: 55 tests across 6 suites

## Running Tests

### All Tests
```bash
make test                    # Run complete test suite
```

### Individual Suites
```bash
make test-core              # Core functionality
make test-h1-h2             # Memory & error handling
make test-m1-m2             # Limits & statistics
make test-m3                # Simple parse mode
make test-m4                # Streaming support
make test-large             # Large data handling
```

### Direct Execution
```bash
cd tests
luajit run_all_tests.lua    # Run all with summary
luajit test_core.lua         # Run specific suite
```

## Examples

### Running Examples
```bash
make example-basic           # Basic usage patterns
make example-streaming       # Streaming examples
```

### Direct Execution
```bash
cd examples
luajit basic_usage.lua
luajit streaming_usage.lua
```

## Benefits of New Structure

1. **Clear Separation**
   - Tests separated from examples
   - Task-specific test organization
   - Easier to find relevant tests

2. **Better Discoverability**
   - README in each directory
   - Descriptive file names
   - Makefile targets for common tasks

3. **Maintainability**
   - Centralized test runner
   - Consistent structure
   - Easy to add new tests

4. **Documentation**
   - Self-documenting structure
   - README files explain purpose
   - Examples show real usage

## Adding New Tests

1. Create `tests/test_<feature>.lua`
2. Follow existing test harness pattern
3. Add to `tests/run_all_tests.lua`
4. Add Makefile target if needed
5. Update `tests/README.md`

## Adding New Examples

1. Create `examples/<name>.lua`
2. Add usage documentation
3. Add Makefile target
4. Update `examples/README.md`

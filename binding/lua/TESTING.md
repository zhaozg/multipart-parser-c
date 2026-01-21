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
│   ├── test_core.lua        # Core functionality tests
│   ├── test_state.lua       # State management tests
│   ├── test_streaming.lua   # Streaming support tests
│   └── test_large_data.lua  # Large data handling tests
└── examples/                # Example code directory
    ├── README.md            # Examples documentation
    ├── basic_usage.lua      # Basic usage patterns
    └── streaming_usage.lua  # Advanced streaming examples
```

## Test Organization

### Naming Convention
- `test_*.lua` - Test suites
- `test_<feature>.lua` - Feature-specific tests

### Test Categories

1. **Core Parsing & Error Handling** (test_core.lua - 27 tests)
   - Module loading and version
   - Parser initialization
   - Basic parsing with callbacks
   - Multi-part parsing, chunked parsing
   - Binary data, UTF-8 support
   - Callback mechanisms (pause/resume)
   - Header accumulation
   - Simple parse function
   - Error handling (callback errors, error state management)

2. **State Management** (test_state.lua - 3 tests)
   - Parser reset with new boundary
   - Parser reset keeping same boundary
   - Parser reset clears error state
   - Memory limit parameters and enforcement
   - Memory tracking (with/without limits)
   - Parser reset with new/same boundary
   - Parser reset clearing error state
   - Streaming with memory limits
   - Memory leak verification

3. **Streaming & Progress Callbacks** (test_streaming.lua - 14 tests)
   - Progress callback functionality
   - Progress parameters and tracking
   - Interrupt/pause parsing
   - Multiple parts progress
   - Feed method (chunked feeding)
   - Pause/resume functionality
   - Incremental parsing
   - Streaming error handling

4. **Large Data Handling** (test_large_data.lua)
   - Performance tests
   - 4GB data simulation
   - Memory safety validation

## Running Tests

### All Tests
```bash
make test                    # Run complete test suite
```

### Individual Suites
```bash
make test-core              # Core functionality
make test-state             # State management
make test-streaming         # Streaming support
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
   - Feature-based test organization
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

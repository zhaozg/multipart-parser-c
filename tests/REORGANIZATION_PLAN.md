# Test Suite Reorganization Plan

## Current Status

The test suite in `test.c` has grown to 1909 lines and contains 37 comprehensive tests organized into 10 sections:

1. **Section 1**: Basic Parser Tests (7 tests)
2. **Section 2**: Binary Data Edge Case Tests (6 tests)
3. **Section 3**: RFC 2046 Compliance Tests (4 tests)
4. **Section 4**: Issue Regression Tests (1 test)
5. **Section 5**: Error Handling Tests (3 tests)
6. **Section 6**: Coverage Improvement Tests (4 tests)
7. **Section 7**: Callback Buffering Tests (1 test)
8. **Section 8**: Parser Reset Tests (5 tests)
9. **Section 9**: RFC 7578 Specific Tests (4 tests)
10. **Section 10**: Safety and Robustness Tests (2 tests)

## Proposed Structure

Move to a `tests/` directory with modular organization:

```
tests/
├── test_common.h          # Shared macros, helpers, test counters
├── test_basic.c           # Section 1: Basic parser functionality
├── test_binary.c          # Section 2: Binary data edge cases
├── test_rfc.c             # Section 3 & 9: RFC compliance (2046 & 7578)
├── test_errors.c          # Section 4 & 5: Error handling & regressions
├── test_advanced.c        # Section 6 & 7: Coverage & buffering
├── test_reset.c           # Section 8: Parser reset functionality
├── test_safety.c          # Section 10: Safety & robustness
├── test_main.c            # Main test runner
└── Makefile               # Build system for modular tests
```

## Benefits

1. **Maintainability**: Easier to locate and modify specific test categories
2. **Modularity**: Tests can be run independently or as a suite
3. **Clarity**: Each file has a focused purpose
4. **Extensibility**: Easy to add new test categories

## Implementation Steps

### Phase 1: Preparation (No Breaking Changes)
1. ✅ Create `tests/` directory
2. Create `tests/test_common.h` with shared macros
3. Verify existing tests still pass

### Phase 2: Extract Common Code
1. Move test macros (TEST_START, TEST_PASS, TEST_FAIL) to `test_common.h`
2. Move shared callback structures to header
3. Create helper functions in header

### Phase 3: Split Test Sections
1. Extract Section 1 → `tests/test_basic.c`
2. Extract Section 2 → `tests/test_binary.c`
3. Extract Section 3 & 9 → `tests/test_rfc.c`
4. Extract Section 4 & 5 → `tests/test_errors.c`
5. Extract Section 6 & 7 → `tests/test_advanced.c`
6. Extract Section 8 → `tests/test_reset.c`
7. Extract Section 10 → `tests/test_safety.c`
8. Create `tests/test_main.c` with runner

### Phase 4: Build System Update
1. Create `tests/Makefile` for modular builds
2. Update main Makefile to use `tests/` directory
3. Maintain backward compatibility (`make test` still works)

### Phase 5: Verification
1. Run full test suite: `make test`
2. Run individual tests: `make test_basic`, `make test_binary`, etc.
3. Verify all 37 tests still pass
4. Check with sanitizers (ASAN, UBSan)

### Phase 6: Documentation
1. Update main README with new test structure
2. Add README in `tests/` directory
3. Document how to run individual test suites

## Migration Strategy

To avoid breaking changes during migration:

1. Keep `test.c` temporarily as `test_legacy.c`
2. Build new modular tests alongside
3. Verify both produce identical results
4. Remove legacy after confidence established

## Backward Compatibility

The main `Makefile` should maintain compatibility:

```makefile
# Old way (still works)
test: test_bin
    ./test

# New way (recommended)
test_modular: tests/test_main
    ./tests/test_main

# Individual test suites
test_basic: tests/test_basic
    ./tests/test_basic
```

## Timeline

- **Phase 1-2**: 1-2 hours (infrastructure setup)
- **Phase 3**: 3-4 hours (careful extraction and verification)
- **Phase 4-5**: 1-2 hours (build system and testing)
- **Phase 6**: 1 hour (documentation)

Total estimated time: 6-9 hours of focused work

## Risks and Mitigation

### Risk 1: Breaking Existing Tests
**Mitigation**: Keep `test.c` intact initially, build new structure alongside, compare results

### Risk 2: Missing Dependencies Between Tests
**Mitigation**: Use static analysis to identify shared state, carefully review each section

### Risk 3: Build System Complexity
**Mitigation**: Keep build simple, maintain `make test` as primary interface

## Next Steps

1. Review and approve this plan
2. Begin Phase 1: Create infrastructure
3. Incremental implementation with verification at each step
4. Request review after each phase

## Notes

- All 37 tests must continue to pass
- No functional changes to test logic
- Pure reorganization for maintainability
- Maintain C89 compatibility

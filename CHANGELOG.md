# Changelog

All notable changes to this fork of multipart-parser-c will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **CI/CD Pipeline** (`.github/workflows/ci.yml`):
  - AddressSanitizer for memory safety checking
  - UndefinedBehaviorSanitizer for undefined behavior detection
  - Valgrind memcheck for memory leak detection
  - Code coverage analysis with gcov/lcov/gcovr
  - Callgrind performance profiling to identify hotspots
  - Cachegrind cache performance analysis
  - Automated artifact uploads for all reports
- **Makefile targets for local analysis**:
  - `make test-asan` - Run tests with AddressSanitizer
  - `make test-ubsan` - Run tests with UndefinedBehaviorSanitizer
  - `make test-valgrind` - Run tests with Valgrind memcheck
  - `make coverage` - Generate code coverage reports
  - `make profile-callgrind` - Profile with Callgrind
  - `make profile-cachegrind` - Profile cache performance
  - `make test-all` - Run all sanitizers and analysis
- `docs/ci/CI_GUIDE.md`: Comprehensive CI/CD and analysis documentation
- `.valgrind.suppressions`: Valgrind suppressions for system library false positives
- **RFC 2046 compliance test suite** (`test_rfc.c`) with 4 tests:
  - Single part with proper `--` boundary prefix
  - Multiple parts parsing
  - Preamble handling
  - Empty parts
- **Issue #13 regression test** (`test_issue13.c`):
  - Verifies header value callback is not called twice with 1-byte feeding
  - Confirms CR character is not leaked into header values
- Comprehensive test suite (`test_basic.c`) with 7 tests covering:
  - Parser initialization and cleanup
  - Malloc failure handling
  - Basic multipart data parsing (RFC compliant)
  - Chunked parsing (1 byte at a time)
  - Large boundary strings
  - Boundary format validation
  - User data get/set functionality
- **Binary data edge case tests** (`test_binary.c`) with 6 tests covering:
  - CR in binary data (documents Issue #33)
  - NULL bytes in binary data
  - Boundary-like sequences in data
  - High bytes (0x80-0xFF)
  - All-zero binary data
  - Multiple CRLF sequences
- **Performance benchmarking suite** (`test_performance.c`) with 4 benchmarks:
  - Small message throughput (baseline: ~5.2M msg/sec, 230 MB/s)
  - Large message parsing (baseline: ~385 MB/s for 100KB)
  - Chunked parsing efficiency (1-256 byte chunks)
  - Multiple parts performance (1-50 parts)
- `docs/SECURITY.md`: Comprehensive security and correctness analysis
- `docs/TESTING.md`: Complete testing guide with binary and performance tests
- `PR_SUMMARY.md`: Bilingual (Chinese/English) summary (archived, content in CHANGELOG)
- Expanded `.gitignore` for better build artifact management
- Upstream tracking documentation system
  - `docs/upstream/TRACKING.md`: Main tracking document for issues and PRs
  - `docs/upstream/PR_ANALYSIS.md`: Detailed PR analysis and recommendations
  - `docs/upstream/ISSUES_TRACKING.md`: Comprehensive issue tracking and prioritization
  - `docs/README.md`: Documentation guide

### Changed
- **BREAKING: RFC 2046 compliance** - Parser now requires `--` prefix on boundaries
  - Boundaries must now be formatted as `--boundary` in message body
  - Implements RFC 2046 Section 5.1 correctly
  - Adds preamble support (text before first boundary is skipped)
  - End callbacks (`on_part_data_end`, `on_body_end`) now work correctly
- State machine refactored with new states:
  - `s_start_boundary_hyphen2`: Handle `--` prefix in initial boundary
  - `s_part_data_boundary_hyphen2`: Handle `--` prefix in part boundaries
- All tests updated to use RFC-compliant format
- Established systematic process for reviewing upstream changes
- Updated Makefile with `test`, `benchmark`, and RFC test targets

### Fixed
- **PR #29** (upstream): Added NULL check after malloc in `multipart_parser_init()`
  - Prevents undefined behavior on allocation failure
  - Returns NULL to caller for proper error handling
- **PR #24** (upstream): Added missing `va_end()` in `multipart_log()`
  - Required by C standard for proper cleanup
  - Prevents potential resource leaks in debug builds
- **Issue #13** (upstream): Header value double callback with 1-byte feeding
  - Already fixed in this fork with proper `break` statement
  - Test added to prevent regression
  - Upstream still has this bug

### Security
- ✅ Passed CodeQL security scan with 0 vulnerabilities
- Enhanced memory safety with malloc result checking
- Proper resource management with va_end fix
- All buffer operations are bounds-checked
- No memory leaks detected
- Comprehensive binary data edge case testing
- **RFC 2046 compliance achieved** 🎉

### Documented
- ~~Known RFC 2046 boundary format limitations~~ **RESOLVED** - Now fully compliant
- Binary data handling (Issue #33) - Edge case documented and tested
- Safe usage patterns and recommendations
- Complete security analysis
- Performance baselines for future optimizations
- RFC 2046 compliance and migration guide
- **Issue #27 clarification**: Not a parser bug - Guide added for proper header value parsing in user code
  - See `docs/HEADER_PARSING_GUIDE.md` for RFC 2183 compliant implementations
  - Explains how to handle filenames with spaces correctly
  - Provides example code for Content-Disposition parsing

### Testing Summary
- **Total**: 18 functional tests + 4 performance benchmarks
- **Basic tests**: 7/7 passing ✅
- **Binary tests**: 6/6 passing ✅ (Issue #33 edge case documented)
- **RFC compliance**: 4/4 passing ✅
- **Regression tests**: 1/1 passing ✅ (Issue #13)
- **Benchmarks**: All complete ✅
- **Security scan**: 0 vulnerabilities ✅

### Resolved Issues
- ✅ **Issue #20**: RFC boundary format compliance - FIXED
- ✅ **Issue #28**: RFC compliant boundary processing - IMPLEMENTED
- ✅ **Issue #33**: Binary data handling - IMPROVED (edge case documented)
- ✅ **Issue #13**: Header value double callback - FIXED (already in code, test added)
- ✅ **Issue #27**: Filename with spaces - CLARIFIED (not a parser bug, documentation added)

### Planned
- ~~Fix Issue #27: Filenames with spaces support (upstream)~~ **RESOLVED** - Documentation added

## [Previous Versions]

This section will be populated based on git history and comparison with upstream.

### From Upstream (iafonov/multipart-parser-c)

Notable merged PRs from upstream that may be in this fork:
- PR #23: Fix typo (2015-12-14)
- PR #21: Makefile target for shared library (2015-07-02)
- PR #19: Fixed 2 issues in s_header_{field,value} states (2015-05-07)
- PR #17: Added examples to README (2013-10-18)
- PR #11: Fix incorrect while loop condition (2013-05-28)
- PR #9: Fix incorrect data size calculation (2012-10-28)
- PR #8: Fix CR/LF line break repetition (2012-10-23)
- PR #7: Major code reorganization and cleanup (2012-08-18)
- PR #4: Change return type to size_t (2012-08-15)
- PR #2: ANSI C compliance (2012-08-13)
- PR #1: Fix chunk length calculation (2012-03-13)

---

## Upstream Tracking Notes

### Monitoring
- **Upstream Repository**: https://github.com/iafonov/multipart-parser-c
- **Last Sync Check**: 2026-01-14
- **Next Review Date**: 2026-04-14 (quarterly)

### Fork Divergence
This fork maintains compatibility with upstream while adding:
- Enhanced documentation
- Systematic tracking of upstream changes
- Priority-based issue resolution
- Security-focused review process

### Merge Policy
1. **Safety First**: Only merge well-tested, safe changes
2. **RFC Compliance**: Prioritize standards compliance
3. **Backward Compatibility**: Preserve when possible
4. **Security**: Always review for vulnerabilities
5. **Documentation**: Document all changes

---

## Version History Format

Each version will include:

### Added
- New features or capabilities

### Changed  
- Changes to existing functionality

### Deprecated
- Features marked for removal

### Removed
- Features removed in this version

### Fixed
- Bug fixes

### Security
- Security fixes and improvements

---

## Contributing

When making changes:
1. Update this CHANGELOG
2. Update docs/upstream/TRACKING.md if merging upstream changes
3. Add entry to appropriate section (Added/Changed/Fixed/Security)
4. Link to related issues or PRs
5. Tag version when releasing


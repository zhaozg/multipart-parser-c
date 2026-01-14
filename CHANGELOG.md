# Changelog

All notable changes to this fork of multipart-parser-c will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test suite (`test_basic.c`) with 7 tests covering:
  - Parser initialization and cleanup
  - Malloc failure handling
  - Basic multipart data parsing
  - Chunked parsing (1 byte at a time)
  - Large boundary strings
  - Invalid boundary detection
  - User data get/set functionality
- `SECURITY_IMPROVEMENTS.md`: Comprehensive security and correctness analysis
- Expanded `.gitignore` for better build artifact management
- Upstream tracking documentation system
  - `UPSTREAM_TRACKING.md`: Main tracking document for issues and PRs
  - `docs/PR_ANALYSIS.md`: Detailed PR analysis and recommendations
  - `docs/ISSUES_TRACKING.md`: Comprehensive issue tracking and prioritization
  - `docs/README.md`: Documentation guide

### Changed
- Established systematic process for reviewing upstream changes

### Fixed
- **PR #29** (upstream): Added NULL check after malloc in `multipart_parser_init()`
  - Prevents undefined behavior on allocation failure
  - Returns NULL to caller for proper error handling
- **PR #24** (upstream): Added missing `va_end()` in `multipart_log()`
  - Required by C standard for proper cleanup
  - Prevents potential resource leaks in debug builds

### Security
- ✅ Passed CodeQL security scan with 0 vulnerabilities
- Enhanced memory safety with malloc result checking
- Proper resource management with va_end fix
- All buffer operations are bounds-checked
- No memory leaks detected

### Documented
- Known RFC 2046 boundary format limitations (Issue #20/#28)
- Binary data handling limitations (Issue #33)
- Safe usage patterns and recommendations
- Complete security analysis

### Planned
- Review PR #28: RFC-compliant boundary processing (upstream)
- Fix Issue #33: Binary data handling in multipart packets (upstream)
- Fix Issue #27: Filenames with spaces support (upstream)

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
2. Update UPSTREAM_TRACKING.md if merging upstream changes
3. Add entry to appropriate section (Added/Changed/Fixed/Security)
4. Link to related issues or PRs
5. Tag version when releasing


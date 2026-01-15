# Documentation Index

This directory contains comprehensive documentation for the multipart-parser-c project.

## Core Documentation

### [TESTING.md](TESTING.md)
Complete testing guide covering:
- Running tests locally
- Test suite structure (basic, binary, RFC compliance, regression)
- Writing new tests
- Integration with CI/CD

### [SECURITY.md](SECURITY.md)
Security improvements and analysis:
- Memory safety enhancements
- Applied upstream security fixes (PR #29, #24)
- CodeQL scanning results
- Safe usage patterns

### [HEADER_PARSING_GUIDE.md](HEADER_PARSING_GUIDE.md)
Guide for parsing header values in user code:
- How to correctly parse Content-Disposition headers
- Handling filenames with spaces (Issue #27 context)
- RFC 2183 compliant implementation examples

## CI/CD Documentation

### [ci/CI_GUIDE.md](ci/CI_GUIDE.md)
Comprehensive CI/CD infrastructure guide:
- GitHub Actions workflow overview
- Local development tools (sanitizers, coverage, profiling)
- Interpreting results from each tool
- Performance optimization workflow
- Troubleshooting and best practices

## Upstream Tracking

### [upstream/TRACKING.md](upstream/TRACKING.md)
Main tracking document for upstream repository:
- Summary of open issues and PRs
- Priority recommendations
- Merge decisions and testing guidelines

### [upstream/PR_ANALYSIS.md](upstream/PR_ANALYSIS.md)
Detailed technical analysis of upstream pull requests:
- Code changes review
- Security assessment
- Impact analysis and merge recommendations

### [upstream/ISSUES_TRACKING.md](upstream/ISSUES_TRACKING.md)
Comprehensive tracking of upstream issues:
- Issue categorization by priority
- Technical problem descriptions
- Proposed solutions and action plans

## Quick Links

- **[../README.md](../README.md)** - Main project README
- **[../CHANGELOG.md](../CHANGELOG.md)** - Version history and changes

## Documentation Structure

```
docs/
├── README.md                    # This file - documentation index
├── TESTING.md                   # Testing guide
├── SECURITY.md                  # Security improvements
├── HEADER_PARSING_GUIDE.md      # User guide for header parsing
├── ci/
│   └── CI_GUIDE.md             # CI/CD infrastructure guide
└── upstream/
    ├── TRACKING.md             # Main upstream tracking
    ├── PR_ANALYSIS.md          # Upstream PR analysis
    └── ISSUES_TRACKING.md      # Upstream issue tracking
```

## Contributing to Documentation

When updating documentation:
1. Keep factual and objective
2. Include links to related issues/PRs
3. Document testing done
4. Note security implications
5. Update this index if adding new files


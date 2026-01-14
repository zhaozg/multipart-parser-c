# Upstream Tracking Documentation

This directory contains documentation for tracking and analyzing the upstream repository [iafonov/multipart-parser-c](https://github.com/iafonov/multipart-parser-c).

## Documents

### [UPSTREAM_TRACKING.md](../UPSTREAM_TRACKING.md)
Main tracking document providing:
- Overview of upstream repository status
- Summary of open issues and PRs
- Priority recommendations
- Testing guidelines
- Tracking process

### [PR_ANALYSIS.md](PR_ANALYSIS.md)
Detailed technical analysis of each upstream pull request:
- Code changes review
- Security assessment
- Impact analysis
- Merge recommendations
- Testing requirements

### [ISSUES_TRACKING.md](ISSUES_TRACKING.md)
Comprehensive tracking of upstream issues:
- Issue categorization by priority
- Technical problem descriptions
- Proposed solutions
- Action plans
- Timeline recommendations

## Quick Reference

### Ready to Merge (Safe)
- **PR #29**: Check malloc result ✅
- **PR #24**: Fix va_end ✅

### Needs Review
- **PR #28**: RFC boundary compliance ⚠️
- **PR #25**: Fix CR in data ⚠️

### Critical Issues
- **Issue #33**: Binary data handling 🔴
- **Issue #20**: RFC compliance 🟡
- **Issue #27**: Filenames with spaces 🟡

## Update Process

1. **Quarterly Review** (every 3 months):
   - Check for new upstream issues/PRs
   - Update priority assessments
   - Review merge status

2. **Monthly Check** (security):
   - Scan for security-related issues
   - Monitor critical bugs

3. **After Each Merge**:
   - Update tracking documents
   - Document in CHANGELOG
   - Tag version if appropriate

## Decision Framework

### When to Merge a PR

✅ **Merge if**:
- Clear bug fix with no side effects
- Safety improvement (malloc checks, etc.)
- Code cleanup with no functional changes
- Well-tested with provided test cases

⚠️ **Review carefully if**:
- Changes core parsing logic
- Affects state machine
- RFC compliance changes
- Potential breaking changes

❌ **Don't merge if**:
- Introduces security vulnerabilities
- Breaks backward compatibility (without major version)
- Insufficient testing
- Unclear benefit/risk ratio

### When to Fix an Issue

🔴 **Critical** (fix immediately):
- Data corruption bugs
- Security vulnerabilities
- Common use case failures

🟡 **High** (fix soon):
- RFC compliance issues
- Usability problems
- Performance issues

🟢 **Medium** (plan fix):
- Edge case bugs
- API design issues
- Documentation gaps

🔵 **Low** (nice to have):
- Rare edge cases
- Enhancement requests
- Minor optimizations

## Contributing

When updating these documents:

1. Keep factual and objective
2. Include links to upstream issues/PRs
3. Document testing done
4. Note security implications
5. Update last modified date

## Related Files

- `../README.md` - Main project README
- `../CHANGELOG.md` - Change history (to be created)
- `../multipart_parser.c` - Main parser implementation
- `../multipart_parser.h` - Public API


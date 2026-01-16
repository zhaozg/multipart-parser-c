# RFC Documentation

This directory contains detailed documentation about RFC compliance for the multipart-parser-c library.

## Documents

### [RFC_7578_COMPLIANCE.md](RFC_7578_COMPLIANCE.md)
**Complete RFC 7578 compliance guide**

This is the primary reference document that covers:
- RFC 7578 requirements in detail
- Implementation compliance status
- Test coverage for each requirement
- Security considerations
- Usage examples
- Application responsibilities

**Start here** if you want to understand how the library implements RFC 7578.

### [RFC_COMPARISON.md](RFC_COMPARISON.md)
**Comparison of RFC standards**

This document explains:
- Evolution of multipart/form-data standards
- Differences between RFC 2046, RFC 2388 (obsolete), and RFC 7578
- Backward compatibility information
- When to use which RFC
- Transition strategy

**Start here** if you want to understand the history and differences between RFC versions.

## Quick Reference

### Current Standards (2026)

| RFC | Status | Purpose |
|-----|--------|---------|
| **RFC 7578** | ✅ **CURRENT** | multipart/form-data specification |
| **RFC 2046** | ✅ Active | MIME multipart foundation |
| RFC 2388 | ❌ **OBSOLETE** | Replaced by RFC 7578 |

### Key RFC 7578 Features

1. **Default Charset**: UTF-8 (not ISO-8859-1)
2. **Empty Fields**: MUST be sent (zero-length content)
3. **Multiple Files**: Explicitly allowed with same field name
4. **Filename Encoding**: RFC 5987 recommended for non-ASCII
5. **Charset Parameter**: NOT allowed on top-level Content-Type

### Implementation Status

✅ **Fully Compliant** at protocol level:
- Boundary parsing (RFC 2046 + RFC 7578)
- Binary-safe data handling
- Empty parts support
- Multiple parts with same name
- Preamble support

⚠️ **Application Responsibility**:
- Content-Disposition parsing
- Filename extraction
- RFC 5987 decoding
- Security validations

See [RFC_7578_COMPLIANCE.md](RFC_7578_COMPLIANCE.md) for complete details.

## Additional Resources

### Related Standards
- [RFC 7578](https://tools.ietf.org/html/rfc7578) - multipart/form-data
- [RFC 2046](https://tools.ietf.org/html/rfc2046) - MIME multipart
- [RFC 5987](https://tools.ietf.org/html/rfc5987) - Charset encoding for headers
- [RFC 2183](https://tools.ietf.org/html/rfc2183) - Content-Disposition

### Project Documentation
- [../HEADER_PARSING_GUIDE.md](../HEADER_PARSING_GUIDE.md) - How to parse header values
- [../SECURITY.md](../SECURITY.md) - Security considerations
- [../TESTING.md](../TESTING.md) - Testing documentation
- [../../README.md](../../README.md) - Main project documentation

## Test Coverage

The library includes comprehensive RFC compliance tests:

**RFC 7578 Specific Tests:**
- `test_rfc7578_multiple_files_same_name()` - Section 4.3
- `test_rfc7578_utf8_content()` - Default UTF-8 charset
- `test_rfc7578_special_field_name()` - Special characters
- `test_rfc7578_empty_filename()` - Empty filename handling

**RFC 2046 Foundation Tests:**
- `test_rfc2046_single_part()` - Basic structure
- `test_rfc2046_multiple_parts()` - Multiple parts
- `test_rfc2046_preamble()` - Preamble support
- `test_rfc2046_empty_part()` - Empty content

Run tests:
```bash
make test           # All tests
make test-asan      # With AddressSanitizer
make coverage       # Generate coverage report
```

## Contributing

When contributing:
1. Ensure changes maintain RFC 7578 compliance
2. Add tests for new RFC features
3. Update this documentation as needed
4. Reference specific RFC sections in comments

## License

This documentation is part of the multipart-parser-c project.
See the main [LICENSE](../../LICENSE) file for details.

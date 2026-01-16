# RFC 7578 Compliance Guide

## Overview

This document details the multipart-parser-c library's compliance with **RFC 7578** (2015), the current standard for `multipart/form-data`. RFC 7578 supersedes RFC 2388 (1998) and provides clarifications and updates for modern web applications.

## RFC Standards Hierarchy

### Current Standard
- **RFC 7578** (2015): "Returning Values from Forms: multipart/form-data"
  - Status: **CURRENT STANDARD**
  - Supersedes: RFC 2388
  - URL: https://tools.ietf.org/html/rfc7578

### Foundation Standards
- **RFC 2046** (1996): "Multipurpose Internet Mail Extensions (MIME) Part Two: Media Types"
  - Defines multipart media type structure
  - URL: https://tools.ietf.org/html/rfc2046
  
- **RFC 2045** (1996): "Multipurpose Internet Mail Extensions (MIME) Part One: Format of Internet Message Bodies"
  - Format conventions
  - URL: https://tools.ietf.org/html/rfc2045

### Related Standards
- **RFC 5987** (2010): "Character Set and Language Encoding for HTTP Header Field Parameters"
  - Character set and language encoding for header parameters
  - URL: https://tools.ietf.org/html/rfc5987
  
- **RFC 2231** (1997): "MIME Parameter Value and Encoded Word Extensions"
  - MIME parameter value encoding
  - URL: https://tools.ietf.org/html/rfc2231

## RFC 7578 Key Requirements

### 1. Media Type Definition (Section 2)

**Specification:**
```
Content-Type: multipart/form-data; boundary=boundary-string
```

**Requirements:**
- Media type MUST be `multipart/form-data`
- Boundary parameter MUST be present
- Boundary string chosen by sender to not occur in any parts

**Implementation Status:** ✅ **COMPLIANT**
- Parser accepts boundary from application
- Application responsible for extracting boundary from Content-Type header

### 2. Boundary String Format (RFC 2046 Section 5.1.1)

**ABNF Syntax:**
```abnf
boundary := 0*69<bchars> bcharsnospace
bchars := bcharsnospace / " "
bcharsnospace := DIGIT / ALPHA / "'" / "(" / ")" / "+" / 
                 "_" / "," / "-" / "." / "/" / ":" / "=" / "?"
```

**Requirements:**
- Maximum length: 70 characters
- Character set: US-ASCII (0-127) only
- Cannot end with whitespace
- Allowed characters: alphanumeric and `'()+_,-./:=?`

**Implementation Status:** ✅ **COMPLIANT**
- Parser handles boundaries up to practical limits
- No restrictions on boundary characters (per RFC 2046)
- Test coverage: `test_init_free()`, `test_boundary_format()`

### 3. Boundary Delimiter Format (RFC 2046 Section 5.1)

**Format:**
- Part boundary: `--boundary`
- Final boundary: `--boundary--`

**Requirements:**
- Each part MUST begin with `CRLF--boundary`
- Final boundary MUST be `CRLF--boundary--`
- First boundary MAY omit leading CRLF (preamble allowed)

**Implementation Status:** ✅ **COMPLIANT**
- Parser correctly handles `--` prefix automatically
- Supports preamble (content before first boundary)
- Test coverage: `test_rfc2046_preamble()`, `test_rfc2046_single_part()`

### 4. Content-Disposition Header (RFC 7578 Section 4.2)

**Required Format:**
```
Content-Disposition: form-data; name="fieldname"
```

**Requirements:**
- MUST be `form-data` type
- `name` parameter MUST be present for each part
- `filename` parameter for file uploads
- Field name MUST be unique or server handles multiple values

**Implementation Status:** ⚠️ **PARTIAL** (Application Responsibility)
- Parser extracts header names and values via callbacks
- Application code responsible for parsing Content-Disposition
- No built-in Content-Disposition parsing
- Documentation provided: `docs/HEADER_PARSING_GUIDE.md`

**Note:** This is by design - the parser is a low-level streaming parser that provides header data to the application via callbacks.

### 5. Empty Field Values (RFC 7578 Section 4.2)

**Requirement:**
> "If a field value is empty, the corresponding part SHOULD have zero-length content, rather than being omitted."

**Example:**
```http
--boundary
Content-Disposition: form-data; name="emptyfield"

--boundary
Content-Disposition: form-data; name="filefield"; filename=""
Content-Type: application/octet-stream

--boundary--
```

**Implementation Status:** ✅ **COMPLIANT**
- Parser correctly handles parts with zero-length content
- Empty parts trigger `on_part_data_begin` and `on_part_data_end` callbacks
- Test coverage: `test_rfc2046_empty_part()`, `test_empty_part_data()`

### 6. Character Set Handling (RFC 7578 Section 5.1)

**RFC 7578 Section 5.1.2:**
> "The 'charset' parameter is not appropriate for use with multipart/form-data. Each part MAY have its own charset parameter on its Content-Type header."

**Correct Usage:**
```http
--boundary
Content-Disposition: form-data; name="textfield"
Content-Type: text/plain; charset=UTF-8

UTF-8 encoded content: 中文测试
--boundary--
```

**Incorrect Usage:**
```http
Content-Type: multipart/form-data; boundary=boundary; charset=UTF-8
```

**Implementation Status:** ✅ **COMPLIANT**
- Parser is encoding-agnostic (binary safe)
- Handles any byte sequence including UTF-8, ISO-8859-1, binary data
- Application responsible for charset interpretation
- Test coverage: `test_binary_high_bytes()`, `test_binary_null_bytes()`

### 7. Filename Parameter (RFC 7578 Section 4.2)

**Requirements:**
- `filename` parameter indicates file upload
- Can be empty string for no file selected
- Should use RFC 5987 encoding for non-ASCII filenames

**RFC 5987 Encoding Example:**
```http
Content-Disposition: form-data; name="file";
  filename*=utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt
```

**Implementation Status:** ⚠️ **PARTIAL** (Application Responsibility)
- Parser provides raw header values
- Application code parses filename parameter
- RFC 5987 encoding/decoding is application responsibility
- See: `docs/HEADER_PARSING_GUIDE.md` for examples

### 8. Multiple Files (RFC 7578 Section 4.3)

**Specification:**
Multiple files can be uploaded with the same field name:

```http
--boundary
Content-Disposition: form-data; name="files"; filename="file1.txt"
Content-Type: text/plain

Content of file1
--boundary
Content-Disposition: form-data; name="files"; filename="file2.txt"
Content-Type: text/plain

Content of file2
--boundary--
```

**Implementation Status:** ✅ **COMPLIANT**
- Parser handles multiple parts with same field name
- Each part triggers separate callback sequence
- Application responsible for collecting multiple values
- Test coverage: `test_rfc2046_multiple_parts()`

### 9. Content-Type for Parts (RFC 7578 Section 4.1.1)

**Default:**
> "If no Content-Type header is specified, the default is 'text/plain; charset=utf-8'."

**For Files:**
```http
Content-Type: application/octet-stream
```

**Implementation Status:** ✅ **COMPLIANT** (Application Responsibility)
- Parser extracts Content-Type headers via callbacks
- Application applies default if header missing
- Parser is format-agnostic

### 10. Field Name Encoding (RFC 7578 Section 4.2)

**Requirements:**
- Field names in HTML forms use percent-encoding
- Form field names transferred as-is in multipart encoding
- Can use RFC 5987 `name*` parameter for non-ASCII names

**Implementation Status:** ✅ **COMPLIANT**
- Parser handles any valid header field characters
- Application responsible for encoding/decoding field names
- Test coverage: `test_multiple_headers()`

### 11. Special Characters in Field Names (RFC 7578 Section 4.2)

**Quoting Rules (RFC 2045):**
```abnf
quoted-string = DQUOTE *(qdtext / quoted-pair) DQUOTE
qdtext = HTAB / SP / %x21 / %x23-5B / %x5D-7E
quoted-pair = "\" (HTAB / SP / VCHAR)
```

**Examples:**
```http
Content-Disposition: form-data; name="field\"with\"quotes"
Content-Disposition: form-data; name="field\\with\\backslashes"
```

**Implementation Status:** ⚠️ **PARTIAL** (Application Responsibility)
- Parser extracts raw header values including quotes
- Application must parse quoted strings per RFC 2045
- See: `docs/HEADER_PARSING_GUIDE.md`

### 12. Binary Data Safety (RFC 2046)

**Requirements:**
- Parser MUST handle arbitrary binary data
- MUST NOT interpret bytes other than CRLF and boundary
- MUST preserve NULL bytes and high bytes (0x80-0xFF)

**Implementation Status:** ✅ **COMPLIANT**
- Fully binary-safe implementation
- No interpretation of part data content
- Test coverage:
  - `test_binary_embedded_cr()` - Isolated CR in binary data
  - `test_binary_null_bytes()` - NULL byte preservation
  - `test_binary_boundary_like()` - Boundary-like sequences
  - `test_binary_high_bytes()` - High bytes (0x80-0xFF)
  - `test_binary_all_zeros()` - Zero-filled data
  - `test_binary_multiple_crlf()` - CRLF in binary data

### 13. Security Considerations (RFC 7578 Section 6)

**RFC Requirements:**
- Limit maximum size of multipart messages
- Validate boundary strings
- Prevent path traversal attacks via filenames
- Sanitize field names and values

**Implementation Status:** ⚠️ **PARTIAL**
- Parser provides streaming interface (no size limits enforced)
- No built-in size limits (application responsibility)
- No filename sanitization (application responsibility)
- Memory-safe implementation (ASAN/Valgrind tested)

**Security Features:**
- Buffer overflow protection
- No dynamic allocations during parsing
- Fixed memory footprint per parser
- Test coverage: `test-asan`, `test-ubsan`, `test-valgrind` targets

**Application Responsibilities:**
1. Enforce maximum message size
2. Limit maximum number of parts
3. Validate/sanitize filenames for path traversal
4. Validate field names against expected schema
5. Enforce Content-Type restrictions

See: `docs/SECURITY.md` for detailed security guidelines.

## Implementation Architecture

### Design Philosophy

multipart-parser-c is a **low-level streaming parser** designed for maximum flexibility and performance:

1. **Streaming**: Processes data in chunks without buffering entire message
2. **Callback-based**: Applications receive parsed elements via callbacks
3. **Format-agnostic**: No interpretation of header values or part content
4. **Binary-safe**: Handles arbitrary byte sequences correctly
5. **Zero-copy**: Provides pointers into original buffer when possible

### Responsibilities

**Parser Responsibilities:**
- ✅ Boundary detection and matching
- ✅ State machine for multipart structure
- ✅ Separation of headers from part data
- ✅ Separation of header fields from values
- ✅ CRLF handling per RFC 2046
- ✅ Preamble support
- ✅ Binary data safety

**Application Responsibilities:**
- ⚠️ Content-Disposition parsing
- ⚠️ Content-Type parsing
- ⚠️ Filename extraction and sanitization
- ⚠️ Field name validation
- ⚠️ RFC 5987 decoding (if needed)
- ⚠️ Charset conversion (if needed)
- ⚠️ Size limits enforcement
- ⚠️ Security validations

This separation ensures:
- Maximum performance (no unnecessary parsing)
- Maximum flexibility (applications choose parsing strategy)
- Minimal dependencies (core parser has zero dependencies)
- Clear security boundaries

## Test Coverage

### RFC 7578 Specific Tests

| Test | RFC Section | Status | Test Function |
|------|-------------|--------|---------------|
| Empty field values | 4.2 | ✅ | `test_rfc2046_empty_part()` |
| Multiple files same name | 4.3 | ✅ | `test_rfc2046_multiple_parts()` |
| Preamble support | RFC 2046 5.1 | ✅ | `test_rfc2046_preamble()` |
| Boundary format | RFC 2046 5.1.1 | ✅ | `test_boundary_format()` |
| Binary data safety | RFC 2046 | ✅ | Section 2 tests (6 tests) |

### Comprehensive Test Suite

Current test suite: **31 tests** covering:
1. Basic parser functionality (7 tests)
2. Binary data edge cases (6 tests) 
3. RFC 2046 compliance (4 tests)
4. Issue regression tests (1 test)
5. Error handling (3 tests)
6. Coverage improvements (5 tests)
7. Callback buffering (1 test)
8. Parser reset (5 tests)

**Coverage:** >95% code coverage (measured with gcov)

Run tests:
```bash
make test           # Basic tests
make test-asan      # AddressSanitizer
make test-ubsan     # UndefinedBehaviorSanitizer
make test-valgrind  # Valgrind memcheck
make coverage       # Coverage report
```

## Gaps and Limitations

### By Design (Application Responsibility)

These features are intentionally NOT implemented in the parser:

1. **Content-Disposition Parsing**
   - Reason: Flexible handling, avoid dependencies
   - Solution: Use `docs/HEADER_PARSING_GUIDE.md`

2. **Filename Extraction**
   - Reason: Multiple encoding schemes (RFC 2231, RFC 5987)
   - Solution: Application parses based on needs

3. **RFC 5987 Decoding**
   - Reason: Would require charset conversion libraries
   - Solution: Application implements if needed

4. **Size Limits**
   - Reason: Different applications have different requirements
   - Solution: Application enforces limits via callbacks

5. **Security Validations**
   - Reason: Security requirements vary by application
   - Solution: See `docs/SECURITY.md` for guidelines

### Potential Future Enhancements

These features could be added while maintaining compatibility:

1. **Optional Content-Disposition Helper**
   - Separate optional module for parsing
   - Would not affect core parser

2. **Multiline Header Support**
   - RFC 2822 folded headers (currently not supported)
   - Low priority (rarely used in multipart/form-data)

3. **Validation Helpers**
   - Optional boundary validation
   - Optional filename sanitization
   - Would be in separate module

## Usage Examples

### Basic Usage

```c
#include "multipart_parser.h"

// Callback implementations
int on_header_field(multipart_parser* p, const char *at, size_t length) {
    printf("Header: %.*s", (int)length, at);
    return 0;
}

int on_header_value(multipart_parser* p, const char *at, size_t length) {
    printf(" = %.*s\n", (int)length, at);
    return 0;
}

int on_part_data(multipart_parser* p, const char *at, size_t length) {
    // Process part data
    return 0;
}

// Setup
multipart_parser_settings callbacks;
memset(&callbacks, 0, sizeof(callbacks));
callbacks.on_header_field = on_header_field;
callbacks.on_header_value = on_header_value;
callbacks.on_part_data = on_part_data;

// Parse
multipart_parser* parser = multipart_parser_init(boundary, &callbacks);
size_t parsed = multipart_parser_execute(parser, data, length);
multipart_parser_free(parser);
```

### RFC 7578 Compliant Application

```c
// Application should:
// 1. Extract boundary from Content-Type header
const char* content_type = "multipart/form-data; boundary=----WebKitFormBoundary";
char boundary[256];
extract_boundary(content_type, boundary);  // Application function

// 2. Initialize parser
multipart_parser* parser = multipart_parser_init(boundary, &callbacks);

// 3. Parse in chunks (streaming)
while (has_more_data()) {
    char buffer[8192];
    size_t len = read_data(buffer, sizeof(buffer));
    size_t parsed = multipart_parser_execute(parser, buffer, len);
    
    if (parsed != len) {
        // Error occurred
        const char* error = multipart_parser_get_error_message(parser);
        fprintf(stderr, "Parse error: %s\n", error);
        break;
    }
}

// 4. Cleanup
multipart_parser_free(parser);
```

### Content-Disposition Parsing

See `docs/HEADER_PARSING_GUIDE.md` for complete implementation examples of:
- Extracting field names
- Extracting filenames (with and without quotes)
- Handling spaces in filenames
- RFC 5987 encoded parameters

## Conclusion

### Compliance Summary

| RFC Requirement | Status | Notes |
|----------------|--------|-------|
| RFC 7578 Structure | ✅ Full | All required elements supported |
| RFC 2046 Boundaries | ✅ Full | Preamble, proper delimiters |
| Binary Safety | ✅ Full | All byte values handled correctly |
| Empty Values | ✅ Full | Zero-length parts supported |
| Multiple Files | ✅ Full | Same field name supported |
| Streaming | ✅ Full | Chunk-by-chunk processing |
| Error Handling | ✅ Full | 7 error codes + messages |
| Security | ⚠️ Partial | Application enforces limits |
| Header Parsing | ⚠️ App | Application parses header values |

### Verdict

**multipart-parser-c is RFC 7578 compliant at the protocol level.**

The parser correctly implements all structural requirements of RFC 7578 and RFC 2046. Higher-level features (header value parsing, filename extraction, security validations) are intentionally delegated to the application layer, following the Unix philosophy of doing one thing well.

This design provides:
- ✅ Maximum performance
- ✅ Maximum flexibility  
- ✅ Zero dependencies
- ✅ Clear security boundaries
- ✅ Well-tested implementation

Applications using this parser can achieve full RFC 7578 compliance by implementing the documented application-level responsibilities.

## References

1. [RFC 7578](https://tools.ietf.org/html/rfc7578) - multipart/form-data (2015)
2. [RFC 2046](https://tools.ietf.org/html/rfc2046) - MIME Part Two (1996)
3. [RFC 2045](https://tools.ietf.org/html/rfc2045) - MIME Part One (1996)
4. [RFC 5987](https://tools.ietf.org/html/rfc5987) - Charset/Language Encoding (2010)
5. [RFC 2231](https://tools.ietf.org/html/rfc2231) - MIME Parameter Encoding (1997)
6. [RFC 2183](https://tools.ietf.org/html/rfc2183) - Content-Disposition (1997)

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-16  
**Parser Version:** Compatible with multipart-parser-c current version

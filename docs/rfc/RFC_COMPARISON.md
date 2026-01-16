# RFC Standards Comparison

## Overview

This document compares the relevant RFC standards for multipart/form-data parsing and explains which standards apply to this library.

## Standard Evolution

```
RFC 2046 (1996) ─────────────┐
MIME Multipart Structure     │
                            │
                            ├──> RFC 7578 (2015) ← CURRENT STANDARD
                            │    multipart/form-data
                            │
RFC 2388 (1998) ────────────┘    (obsoletes RFC 2388)
multipart/form-data (obsolete)
```

## RFC 2046 vs RFC 2388 vs RFC 7578

| Feature | RFC 2046 (1996) | RFC 2388 (1998) | RFC 7578 (2015) |
|---------|----------------|-----------------|-----------------|
| **Status** | Active (Foundation) | **OBSOLETE** | **CURRENT** |
| **Purpose** | MIME multipart structure | Form data (obsolete) | Form data (current) |
| **Boundary Format** | Defines syntax | Inherits from 2046 | Inherits from 2046 |
| **Default Charset** | Not specified | ISO-8859-1 implied | **UTF-8** |
| **Empty Fields** | Not addressed | Not addressed | **MUST be sent** |
| **Charset Parameter** | Allowed | Unclear | **NOT allowed** on top-level |
| **Filename Encoding** | Basic | Basic | **RFC 5987 support** |
| **Multiple Files** | Not addressed | Not addressed | **Explicitly allowed** |

## Key Differences: RFC 2388 → RFC 7578

### 1. Default Character Encoding

**RFC 2388 (1998):**
- Ambiguous about default charset
- Led to inconsistent implementations
- Many used ISO-8859-1 by default

**RFC 7578 (2015):**
- **Default is UTF-8** for text fields
- Each part can specify its own charset
- Charset parameter NOT allowed on multipart/form-data itself

**Example (RFC 7578 Compliant):**
```http
Content-Type: multipart/form-data; boundary=boundary

--boundary
Content-Disposition: form-data; name="comment"
Content-Type: text/plain; charset=UTF-8

中文评论
--boundary--
```

**Incorrect (Not RFC 7578 Compliant):**
```http
Content-Type: multipart/form-data; boundary=boundary; charset=UTF-8
```

### 2. Empty Field Values

**RFC 2388:**
- Silent on handling empty values
- Implementation-defined behavior

**RFC 7578 Section 4.2:**
> "If a field value is empty, then the corresponding part SHOULD have zero-length content, rather than being omitted."

**Correct:**
```http
--boundary
Content-Disposition: form-data; name="optionalfield"

--boundary--
```

### 3. Filename Encoding

**RFC 2388:**
- Basic ASCII filenames
- No standard for non-ASCII names

**RFC 7578:**
- Recommends RFC 5987 encoding for non-ASCII
- Backward compatible with ASCII filenames

**RFC 5987 Example:**
```http
Content-Disposition: form-data; name="file"; 
  filename*=utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt
```

### 4. Multiple Files with Same Name

**RFC 2388:**
- Not explicitly addressed

**RFC 7578 Section 4.3:**
- Explicitly allows multiple files with same field name
- Server responsible for handling multiple values

**Example:**
```http
--boundary
Content-Disposition: form-data; name="files"; filename="file1.txt"

...
--boundary
Content-Disposition: form-data; name="files"; filename="file2.txt"

...
--boundary--
```

### 5. Content-Type Defaults

**RFC 2388:**
- Ambiguous defaults

**RFC 7578 Section 4.1.1:**
- **Default for text fields:** `text/plain; charset=utf-8`
- **For files:** Should specify actual type or use `application/octet-stream`

## Implementation Impact

### What Changed for Parsers

Most changes are **clarifications**, not breaking changes:

1. ✅ **No parser changes needed** - RFC 7578 clarifies RFC 2046
2. ✅ **Binary safety** - Already required by RFC 2046
3. ✅ **Empty values** - Already handled by proper RFC 2046 parsing
4. ⚠️ **UTF-8 default** - Application-level concern (charset interpretation)
5. ⚠️ **RFC 5987** - Application-level concern (filename parsing)

### multipart-parser-c Compliance

| Requirement | RFC 2046 | RFC 2388 | RFC 7578 | Implementation |
|-------------|----------|----------|----------|----------------|
| Boundary parsing | Required | Required | Required | ✅ Full |
| Preamble support | Optional | Optional | Optional | ✅ Full |
| Empty parts | Allowed | Unclear | Required | ✅ Full |
| Binary safety | Required | Required | Required | ✅ Full |
| CRLF handling | Required | Required | Required | ✅ Full |
| Multiple same-name | N/A | N/A | Allowed | ✅ Full |
| UTF-8 default | N/A | N/A | Recommended | ⚠️ App |
| RFC 5987 | N/A | N/A | Recommended | ⚠️ App |

**Legend:**
- ✅ Full: Implemented in parser
- ⚠️ App: Application responsibility

## When to Use Which RFC

### For Parser Implementation

**Follow RFC 7578 + RFC 2046:**
- RFC 7578 is the current standard
- RFC 2046 defines the underlying structure
- Ignore RFC 2388 (obsolete)

### For Application Development

**Read in Order:**
1. **RFC 7578** - Understand requirements for form data
2. **RFC 2046 Section 5.1** - Understand multipart structure
3. **RFC 5987** - If supporting non-ASCII filenames
4. **RFC 2183** - If parsing Content-Disposition in detail

## Backward Compatibility

### Is RFC 7578 Backward Compatible?

**YES** - RFC 7578 is fully backward compatible:

1. **Boundary format** - Unchanged from RFC 2046
2. **Structure** - Unchanged from RFC 2046
3. **Content-Disposition** - Unchanged from RFC 2183
4. **New features** - All additive (not breaking)

### Can RFC 2388 Clients Work?

**YES** - Old clients/servers continue to work:

- RFC 7578 clarifies ambiguities, doesn't change protocol
- Old parsers work with RFC 7578 messages
- RFC 7578 parsers work with old messages
- Main differences are defaults and recommendations

### Transition Strategy

**For Applications:**
1. ✅ Assume UTF-8 for text fields (unless specified otherwise)
2. ✅ Always send empty fields (don't omit)
3. ✅ Use RFC 5987 for non-ASCII filenames
4. ✅ Don't put charset on top-level Content-Type

**For Parsers:**
1. ✅ Handle all RFC 2046 multipart structures
2. ✅ Be binary-safe (don't interpret content)
3. ✅ Support empty parts
4. ✅ Provide raw headers to application

## Testing Standards Compliance

### RFC 2046 Tests

Structural tests (required foundation):
```c
test_rfc2046_single_part()      // Basic structure
test_rfc2046_multiple_parts()   // Multiple parts
test_rfc2046_preamble()         // Preamble support
test_rfc2046_empty_part()       // Empty content
```

### RFC 7578 Tests

Form-data specific tests:
```c
test_rfc2046_empty_part()          // Empty field values (RFC 7578 4.2)
test_rfc2046_multiple_parts()      // Multiple files (RFC 7578 4.3)
test_binary_*()                    // Binary safety (6 tests)
test_boundary_format()             // Boundary validation
```

### Future Test Additions

Recommended tests for complete coverage:
```c
// Field name with special characters
test_rfc7578_quoted_field_name()

// Multiple files with same name
test_rfc7578_multiple_same_name()

// RFC 5987 filename encoding (application level)
test_rfc5987_filename_encoding()  // If implemented

// UTF-8 default handling (application level)
test_rfc7578_utf8_default()       // If implemented
```

## Summary

### For Parser Developers

✅ **Implement:** RFC 7578 + RFC 2046  
❌ **Ignore:** RFC 2388 (obsolete)  
⚠️ **Reference:** RFC 5987 (if needed for filenames)

### For Application Developers

✅ **Read:** RFC 7578 (requirements)  
✅ **Reference:** RFC 2046 Section 5.1 (structure)  
✅ **Consider:** RFC 5987 (non-ASCII filenames)  
❌ **Ignore:** RFC 2388 (obsolete)

### Key Takeaway

**RFC 7578 = RFC 2046 + clarifications + best practices**

The transition from RFC 2388 to RFC 7578 is about:
- Fixing ambiguities
- Standardizing defaults (UTF-8)
- Documenting best practices
- NOT about breaking changes

A proper RFC 2046 parser (like multipart-parser-c) is already RFC 7578 compliant at the protocol level.

## References

- [RFC 2046 (MIME Part Two)](https://tools.ietf.org/html/rfc2046) - Foundation
- [RFC 2388 (OBSOLETE)](https://tools.ietf.org/html/rfc2388) - Don't use
- [RFC 7578 (CURRENT)](https://tools.ietf.org/html/rfc7578) - Use this
- [RFC 5987 (Charset Encoding)](https://tools.ietf.org/html/rfc5987) - For filenames
- [RFC 2183 (Content-Disposition)](https://tools.ietf.org/html/rfc2183) - For header parsing

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-16

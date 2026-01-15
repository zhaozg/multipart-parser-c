# Header Value Parsing Guide

## Overview

The multipart-parser-c library is a **streaming parser** that provides callbacks with raw header field names and values. The parser itself does **not** interpret or parse header values - it simply passes them to your callbacks as-is. This design keeps the parser lightweight and flexible.

## Common Pitfall: Content-Disposition with Filenames

### Issue #27 Context

Upstream Issue #27 discusses problems with filenames containing spaces. This is **not a bug in the parser** but rather a common mistake in how users parse the `Content-Disposition` header value.

### The Problem

When parsing `Content-Disposition` header values, some implementations incorrectly use `strtok()` with both semicolon (`;`) and space (` `) as delimiters:

```c
/* ❌ INCORRECT - breaks filenames with spaces */
char* token = strtok(value, "; ");
```

This causes problems with headers like:
```
Content-Disposition: form-data; name="file"; filename="my document.pdf"
```

The filename would be incorrectly split into `"my` and `document.pdf"`.

### The Solution

Parse `Content-Disposition` headers correctly by:
1. Only using semicolon (`;`) as the main delimiter
2. Properly handling quoted strings
3. Trimming whitespace only around delimiters, not within quoted values

## Correct Implementation Examples

### Example 1: Simple State Machine Parser

```c
typedef struct {
    char name[256];
    char filename[256];
} disposition_info;

int parse_content_disposition(const char* value, size_t length, 
                               disposition_info* info) {
    size_t i = 0;
    char key[64];
    char val[256];
    int in_quotes = 0;
    
    /* Skip "form-data" or "attachment" etc. */
    while (i < length && value[i] != ';') i++;
    if (i >= length) return 0;
    i++; /* skip semicolon */
    
    while (i < length) {
        /* Skip whitespace */
        while (i < length && (value[i] == ' ' || value[i] == '\t')) i++;
        if (i >= length) break;
        
        /* Read key */
        size_t key_len = 0;
        while (i < length && value[i] != '=' && key_len < sizeof(key) - 1) {
            key[key_len++] = value[i++];
        }
        key[key_len] = '\0';
        
        if (i >= length || value[i] != '=') break;
        i++; /* skip '=' */
        
        /* Read value (may be quoted) */
        size_t val_len = 0;
        in_quotes = (i < length && value[i] == '"');
        if (in_quotes) i++; /* skip opening quote */
        
        while (i < length && val_len < sizeof(val) - 1) {
            if (in_quotes) {
                if (value[i] == '"') {
                    i++; /* skip closing quote */
                    break;
                }
            } else {
                if (value[i] == ';') break;
            }
            val[val_len++] = value[i++];
        }
        val[val_len] = '\0';
        
        /* Store the parsed value (with explicit null termination) */
        if (strcmp(key, "name") == 0) {
            strncpy(info->name, val, sizeof(info->name) - 1);
            info->name[sizeof(info->name) - 1] = '\0';  /* Ensure null termination */
        } else if (strcmp(key, "filename") == 0) {
            strncpy(info->filename, val, sizeof(info->filename) - 1);
            info->filename[sizeof(info->filename) - 1] = '\0';  /* Ensure null termination */
        }
        
        /* Skip to next parameter */
        while (i < length && value[i] != ';') i++;
        if (i < length) i++; /* skip semicolon */
    }
    
    return 1;
}
```

### Example 2: Using the Parser Callbacks

```c
typedef struct {
    char current_field[256];
    char filename[512];
    int found_filename;
} parser_context;

int on_header_field(multipart_parser* p, const char* at, size_t length) {
    parser_context* ctx = (parser_context*)multipart_parser_get_data(p);
    
    if (length < sizeof(ctx->current_field)) {
        memcpy(ctx->current_field, at, length);
        ctx->current_field[length] = '\0';
    }
    
    return 0;
}

int on_header_value(multipart_parser* p, const char* at, size_t length) {
    parser_context* ctx = (parser_context*)multipart_parser_get_data(p);
    
    /* Check if this is Content-Disposition */
    if (strcasecmp(ctx->current_field, "Content-Disposition") == 0) {
        disposition_info info;
        memset(&info, 0, sizeof(info));
        
        if (parse_content_disposition(at, length, &info)) {
            if (info.filename[0] != '\0') {
                strncpy(ctx->filename, info.filename, sizeof(ctx->filename) - 1);
                ctx->found_filename = 1;
            }
        }
    }
    
    return 0;
}
```

## Testing Filenames with Spaces

Here's a simple test to verify your header parsing handles filenames correctly:

```c
void test_filename_parsing(void) {
    int i;
    const char* test_cases[] = {
        "form-data; name=\"file\"; filename=\"document.pdf\"",
        "form-data; name=\"file\"; filename=\"my document.pdf\"",
        "form-data; name=\"file\"; filename=\"hello world test.txt\"",
        "form-data; name=\"upload\"; filename=\"file with many   spaces.dat\"",
        NULL
    };
    
    for (i = 0; test_cases[i] != NULL; i++) {
        disposition_info info;
        memset(&info, 0, sizeof(info));
        
        parse_content_disposition(test_cases[i], strlen(test_cases[i]), &info);
        
        printf("Test %d: filename=\"%s\"\n", i + 1, info.filename);
    }
}
```

## RFC 2183 Reference

The correct format for Content-Disposition headers is defined in [RFC 2183](https://tools.ietf.org/html/rfc2183):

```
Content-Disposition: disposition-type *( ";" disposition-parm )

disposition-parm := attribute "=" value
value := token | quoted-string
```

Key points:
- Parameters are separated by semicolons (`;`)
- Values can be tokens (no spaces) or quoted-strings (can contain spaces)
- Whitespace around `=` and `;` is allowed and should be ignored
- Whitespace within quoted strings must be preserved

## Summary

**For multipart-parser-c users:**

1. ✅ The parser correctly passes header values to your callbacks
2. ✅ No changes to the parser are needed
3. ⚠️ **Your responsibility**: Parse header values correctly in your callbacks
4. ⚠️ **Never use**: `strtok(value, "; ")` for Content-Disposition
5. ✅ **Always**: Respect quoted strings and only split on unquoted semicolons

**Issue #27 Status:**
- Not applicable to parser itself (parser works correctly)
- Documentation added to guide users on proper header value parsing
- Example implementations provided above

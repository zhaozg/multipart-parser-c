# Advanced Parsing Examples

This directory contains comprehensive examples demonstrating application-level responsibilities for RFC 7578 compliance in multipart/form-data parsing.

## Overview

The multipart-parser-c library provides low-level protocol parsing. Applications using this library must implement higher-level features for full RFC 7578 compliance. These examples show how to implement:

1. **Content-Disposition Parsing** - Extract field names and filenames from headers
2. **Filename Extraction** - Handle quoted strings and special characters
3. **RFC 5987 Decoding** - Decode percent-encoded UTF-8 filenames
4. **Security Validations** - Prevent path traversal and enforce size limits
5. **Streaming Processing** - Handle boundary conditions in chunked data

## Files

### C Examples

**`advanced_parsing.c`** - Complete C implementation showing:
- Content-Disposition header parsing with quoted strings
- RFC 5987 percent-encoded filename decoding
- Security validations (path traversal prevention, filename sanitization)
- Size limit enforcement during streaming
- Handling split boundaries across chunks
- Complete application integration example

**Build and run:**
```bash
cd examples
cc -o advanced_parsing advanced_parsing.c ../multipart_parser.c -I.. -std=c99
./advanced_parsing
```

**Note:** Uses C99 for loop declarations. For C89, declare loop variables before the loop.

### Lua Examples

**`advanced_example.lua`** - Complete Lua implementation showing:
- Content-Disposition header parsing
- RFC 5987 filename decoding
- Security validations
- Size limit callbacks
- Streaming with boundary splits
- Complete application example

**Run:**
```bash
cd examples
luajit advanced_example.lua
```

## Example Output

### Example 1: Content-Disposition Parsing

```
Input: form-data; name="avatar"; filename="photo.jpg"
  Name: 'avatar'
  Filename: 'photo.jpg'
```

### Example 2: RFC 5987 Decoding

```
Encoded: utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt
Decoded: 中文名.txt
Bytes: E4 B8 AD E6 96 87 E5 90 8D 2E 74 78 74
```

### Example 3: Security Validations

```
Input: ../../../etc/passwd
  Status: REJECTED

Input: normal_file.txt
  Sanitized: normal_file.txt
  Status: OK (SAFE)
```

### Example 4: Size Limits

```
Parsing with limits: max_part=30, max_total=1000
  Part size limit exceeded: 62 > 30
Parsed 123 of 215 bytes
Size limit enforcement working correctly
```

### Example 5: Streaming with Boundary Splits

```
Chunk 4: "Some data\r\n--st"
Chunk 5: "ream\r\n"
Successfully parsed 2 parts with split boundaries
```

## Key Concepts

### Why Applications Must Handle These

The parser operates at the protocol level for maximum performance and flexibility. Application-level features like Content-Disposition parsing and security validations are deliberately left to the application because:

1. **Performance** - Applications can choose parsing strategies for their needs
2. **Flexibility** - Different applications have different security requirements
3. **Zero Dependencies** - Core parser remains lightweight
4. **Clear Boundaries** - Protocol vs. application-level separation

### Streaming and Boundaries

**Critical**: When parsing streaming data, boundaries can be split across chunks:

```
Chunk 1: "data\r\n--bou"
Chunk 2: "ndary\r\n"
```

The parser handles this internally using a lookbehind buffer, but applications must:
- Feed all data to the parser sequentially
- Not make assumptions about callback timing
- Handle callbacks that may be split across chunks

### Security Best Practices

1. **Always sanitize filenames** - Remove path components, reject `.` and `..`
2. **Enforce size limits** - Both per-part and total
3. **Validate field names** - Check against expected schema
4. **Content-Type validation** - Ensure files match expected types
5. **Use RFC 5987 for non-ASCII** - Proper encoding prevents injection

## Integration Guide

### Basic Pattern

```c
// 1. Define state structure
typedef struct {
    char field_name[256];
    char filename[256];
    size_t part_size;
    // ... more fields
} app_state_t;

// 2. Implement callbacks
int on_header_value(multipart_parser* p, const char* at, size_t length) {
    app_state_t* state = multipart_parser_get_data(p);
    
    // Parse Content-Disposition
    if (is_content_disposition(state->last_header)) {
        parse_content_disposition(at, length, state);
        // Sanitize filename if present
        if (state->filename[0]) {
            sanitize_filename(state->filename);
        }
    }
    
    return 0;
}

int on_part_data(multipart_parser* p, const char* at, size_t length) {
    app_state_t* state = multipart_parser_get_data(p);
    
    // Enforce size limits
    state->part_size += length;
    if (state->part_size > MAX_PART_SIZE) {
        return 1;  // Stop parsing
    }
    
    // Write to file or accumulate in memory
    // ...
    
    return 0;
}

// 3. Initialize and parse
multipart_parser_settings settings = {
    .on_header_field = on_header_field,
    .on_header_value = on_header_value,
    .on_part_data = on_part_data,
    // ... other callbacks
};

app_state_t state = {0};
multipart_parser* parser = multipart_parser_init(boundary, &settings);
multipart_parser_set_data(parser, &state);

// 4. Feed data (possibly in chunks)
while (has_more_data()) {
    char buffer[8192];
    size_t len = read_data(buffer, sizeof(buffer));
    multipart_parser_execute(parser, buffer, len);
}

multipart_parser_free(parser);
```

### Lua Pattern

```lua
local state = {
    field_name = nil,
    filename = nil,
    part_size = 0
}

local callbacks = {
    on_header_value = function(data)
        if state.last_header == "Content-Disposition" then
            local disp = parse_content_disposition(data)
            state.field_name = disp.name
            if disp.filename then
                state.filename = sanitize_filename(disp.filename)
            end
        end
        return 0
    end,
    
    on_part_data = function(data)
        state.part_size = state.part_size + #data
        if state.part_size > MAX_PART_SIZE then
            return 1  -- Stop
        end
        -- Write to file or accumulate
        return 0
    end
}

local parser = mp.new(boundary, callbacks)
parser:execute(data)
parser:free()
```

## Performance Considerations

1. **Minimize allocations** - Reuse buffers when possible
2. **Stream to disk** - Don't accumulate large files in memory
3. **Set reasonable limits** - Prevent DoS via large uploads
4. **Use buffering** - Set `buffer_size` in settings for small parts

## References

- [RFC 7578](https://tools.ietf.org/html/rfc7578) - multipart/form-data standard
- [RFC 5987](https://tools.ietf.org/html/rfc5987) - Charset/language encoding
- [RFC 2183](https://tools.ietf.org/html/rfc2183) - Content-Disposition header
- [../docs/rfc/RFC_7578_COMPLIANCE.md](../docs/rfc/RFC_7578_COMPLIANCE.md) - Complete compliance guide
- [../docs/HEADER_PARSING_GUIDE.md](../docs/HEADER_PARSING_GUIDE.md) - Header parsing guide
- [../docs/SECURITY.md](../docs/SECURITY.md) - Security considerations

## Contributing

When adding new examples:
1. Follow the existing structure (numbered examples)
2. Include both C and Lua versions
3. Add clear comments explaining the concepts
4. Test with various input cases
5. Update this README

## License

These examples are part of the multipart-parser-c project.
See the main [LICENSE](../LICENSE) file for details.

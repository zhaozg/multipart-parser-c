# Lua Binding for multipart-parser-c

A complete Lua/LuaJIT binding for the multipart-parser-c library, providing a simple and efficient way to parse and build multipart/form-data in Lua applications.

## Features

- **Full API Coverage**: All parser functionality exposed to Lua
- **LuaJIT Compatible**: Optimized for LuaJIT 2.0+ (also works with Lua 5.1+)
- **Three APIs**: High-level parse()/build() functions and advanced streaming parser
- **Parse & Build**: Parse multipart data or build it from structured Lua tables
- **Stream Processing**: Parse multipart data in chunks without buffering entire content
- **Callback-based**: Efficient event-driven parsing
- **Binary Safe**: Handles binary data (NULL bytes, high bytes) correctly
- **UTF-8 Support**: Properly handles UTF-8 encoded content
- **Error Handling**: Comprehensive error codes and messages
- **High Performance**: Zero-copy data passing, minimal overhead
- **LDoc Documented**: Complete API documentation with examples

## Building

### Prerequisites

- LuaJIT 2.0+ or Lua 5.1+ with development headers
- C compiler (GCC or Clang)
- pkg-config

### Install Dependencies (Ubuntu/Debian)

```bash
sudo apt-get install libluajit-5.1-dev luajit
```

### Build the Binding

```bash
cd binding/lua
make
```

### Install System-wide (Optional)

```bash
cd binding/lua
sudo make install
```

## Usage

The Lua binding provides three levels of API:
1. **High-level**: Simple `parse()` and `build()` functions for common use cases
2. **Low-level**: Streaming parser with callbacks for fine-grained control

### High-Level API

#### Parsing Multipart Data

The `multipart.parse()` function parses a complete multipart message:

```lua
local multipart = require("multipart")

local body = [[
--boundary
Content-Disposition: form-data; name="username"

john_doe
--boundary
Content-Disposition: form-data; name="avatar"; filename="photo.jpg"
Content-Type: image/jpeg

...binary image data...
--boundary--
]]

local content_type = "multipart/form-data; boundary=boundary"
local data = multipart.parse(body, content_type)

-- Access parsed data
print(data.username)  -- "john_doe"
print(data.avatar.filename)  -- "photo.jpg"
print(data.avatar["Content-Type"])  -- "image/jpeg"
print(data.avatar[1])  -- image data
```

#### Building Multipart Data

The `multipart.build()` function creates multipart messages from Lua tables:

```lua
local multipart = require("multipart")

-- Simple fields
local data = {
  username = "john_doe",
  email = "john@example.com"
}

local body, content_type = multipart.build(data)
-- Use body and content_type in HTTP request

-- File upload
local file_data = {
  description = "Profile photo",
  avatar = {
    [1] = file_content,  -- file data
    filename = "photo.jpg",
    ["Content-Type"] = "image/jpeg"
  }
}

local body, content_type = multipart.build(file_data)

-- Multiple files (creates nested multipart/mixed)
local multi_files = {
  documents = {
    { [1] = "doc1 content", filename = "doc1.pdf", ["Content-Type"] = "application/pdf" },
    { [1] = "doc2 content", filename = "doc2.pdf", ["Content-Type"] = "application/pdf" }
  }
}

local body, content_type = multipart.build(multi_files)
```

### Low-Level Streaming Parser

Create a parser with custom callbacks:

```lua
local mp = require("multipart_parser")

-- Define callbacks
local callbacks = {
    on_header_field = function(data)
        print("Header field: " .. data)
        return 0  -- Continue parsing
    end,

    on_header_value = function(data)
        print("Header value: " .. data)
        return 0
    end,

    on_part_data = function(data)
        print("Part data: " .. data)
        return 0
    end,

    on_part_data_begin = function()
        print("Part begins")
        return 0
    end,

    on_headers_complete = function()
        print("Headers complete")
        return 0
    end,

    on_part_data_end = function()
        print("Part ends")
        return 0
    end,

    on_body_end = function()
        print("Body ends")
        return 0
    end
}

-- Create parser
local parser = mp.new("boundary", callbacks)

-- Parse data
local data = [[--boundary
Content-Type: text/plain

Hello, World!
--boundary--]]

local parsed = parser:execute(data)
print("Parsed " .. parsed .. " bytes")

-- Clean up
parser:free()
```

### Chunked Parsing

```lua
local mp = require("multipart_parser")

local parts = {}
local current_part = {headers = {}, data = {}}

local callbacks = {
    on_header_field = function(data)
        current_part.current_field = data
        return 0
    end,

    on_header_value = function(data)
        if current_part.current_field then
            current_part.headers[current_part.current_field] = data
        end
        return 0
    end,

    on_part_data = function(data)
        table.insert(current_part.data, data)
        return 0
    end,

    on_part_data_begin = function()
        current_part = {headers = {}, data = {}}
        return 0
    end,

    on_part_data_end = function()
        current_part.full_data = table.concat(current_part.data)
        table.insert(parts, current_part)
        return 0
    end
}

local parser = mp.new("xyz", callbacks)

-- Parse in chunks (e.g., from network socket)
local chunks = {
    "--xyz\r\n",
    "Content-Disposition: form-data; name=\"field\"\r\n",
    "\r\n",
    "value",
    "\r\n--xyz--"
}

for _, chunk in ipairs(chunks) do
    parser:execute(chunk)
end

-- Access parsed parts
for i, part in ipairs(parts) do
    print(string.format("Part %d:", i))
    for k, v in pairs(part.headers) do
        print(string.format("  %s: %s", k, v))
    end
    print(string.format("  Data: %s", part.full_data))
end

parser:free()
```

### Error Handling

```lua
local mp = require("multipart_parser")

local parser = mp.new("test")
local parsed = parser:execute(data)

-- Check for errors
local err = parser:get_error()
if err ~= mp.ERROR.OK then
    local msg = parser:get_error_message()
    print("Parse error: " .. msg)
end

parser:free()
```

## API Reference

### High-Level Functions (multipart module)

#### `multipart.parse(body, content_type)`

Parse a complete multipart/form-data message into a Lua table.

**Parameters:**
- `body` (string): The multipart message body to parse
- `content_type` (string): Content-Type header value (e.g., "multipart/form-data; boundary=xyz")

**Returns:**
- (table) Parsed data structure where:
  - Simple fields are stored as string values
  - File uploads are stored as tables with `[1]=data`, `filename=name`, and other headers
  - Repeated fields become arrays
  - Parts without names use numeric indices
  - Nested multipart/mixed are parsed recursively

**Example:**
```lua
local multipart = require("multipart")
local data = multipart.parse(body, content_type)
print(data.username)  -- Access field value
print(data.file.filename)  -- Access filename
```

#### `multipart.build(data, [boundary])`

Build a multipart/form-data message from a Lua table.

**Parameters:**
- `data` (table): Data to encode as multipart, where:
  - Simple string values become form fields
  - Tables with `[1]=data` and `filename=name` become file uploads
  - Arrays of values create repeated fields
  - Nested tables with numeric indices become multipart/mixed
- `boundary` (string, optional): Custom boundary string (auto-generated if nil)

**Returns:**
- (string, string) Two values:
  1. The multipart message body
  2. The Content-Type header value (e.g., "multipart/form-data; boundary=xyz")

**Example:**
```lua
local multipart = require("multipart")
local data = {
  username = "john",
  file = {
    [1] = "file content",
    filename = "test.txt",
    ["Content-Type"] = "text/plain"
  }
}
local body, content_type = multipart.build(data)
```

### Low-Level Streaming Parser (multipart_parser module)

#### `mp.new(boundary, [callbacks])`

**Streaming parser** - Create a parser with custom callbacks for fine-grained control.

**Parameters:**
- `boundary` (string): The boundary string (without "--" prefix)
- `callbacks` (table, optional): Table of callback functions

**Returns:**
- Parser object or raises error on failure

**Example:**
```lua
local mp = require("multipart_parser")
local parser = mp.new("boundary123", {
    on_part_data = function(data)
        print(data)
        return 0
    end
})
```

### Parser Methods

#### `parser:execute(data)`

Parse a chunk of multipart data.

**Parameters:**
- `data` (string): Data chunk to parse

**Returns:**
- Number of bytes successfully parsed

**Example:**
```lua
local parsed = parser:execute(chunk)
```

#### `parser:get_error()`

Get the last error code.

**Returns:**
- Error code (number), see `mp.ERROR` for constants

**Example:**
```lua
local err = parser:get_error()
if err ~= mp.ERROR.OK then
    -- Handle error
end
```

#### `parser:get_error_message()`

Get a human-readable error message.

**Returns:**
- Error message (string)

**Example:**
```lua
local msg = parser:get_error_message()
print("Error: " .. msg)
```

#### `parser:reset([boundary])`

Reset the parser to parse a new multipart message. This allows reusing the same parser instance for multiple messages, which is more efficient than creating a new parser each time.

**Parameters:**
- `boundary` (string, optional): New boundary string (without "--" prefix). If omitted or `nil`, keeps the existing boundary.

**Returns:**
- `true` on success, raises error if new boundary is too long

**Example:**
```lua
local parser = mp.new("boundary1", callbacks)

-- Parse first message
parser:execute(data1)

-- Reset with new boundary for second message
parser:reset("boundary2")
parser:execute(data2)

-- Reset keeping same boundary for third message
parser:reset()  -- or parser:reset(nil)
parser:execute(data3)

parser:free()
```

**Notes:**
- Resets parser state to start parsing a new message
- Clears any error state from previous parsing
- Preserves callback settings and user data
- The new boundary (if provided) cannot be longer than the original boundary

#### `parser:free()`

Free parser resources. Called automatically by garbage collector.

**Example:**
```lua
parser:free()
```

### Callbacks

All callbacks are optional. Return 0 to continue parsing, non-zero to pause.

#### `on_header_field(data)`

Called when a header field is parsed.

**Parameters:**
- `data` (string): Header field name

#### `on_header_value(data)`

Called when a header value is parsed.

**Parameters:**
- `data` (string): Header field value

#### `on_part_data(data)`

Called when part data is available.

**Parameters:**
- `data` (string): Part data chunk

#### `on_part_data_begin()`

Called when a new part begins (before headers).

#### `on_headers_complete()`

Called when all headers for a part have been parsed.

#### `on_part_data_end()`

Called when a part ends.

#### `on_body_end()`

Called when the entire multipart body ends.

### Error Constants

Available in `mp.ERROR` table:

- `OK` - No error
- `PAUSED` - Parser paused by callback
- `INVALID_BOUNDARY` - Invalid boundary format
- `INVALID_HEADER_FIELD` - Invalid header field character
- `INVALID_HEADER_FORMAT` - Invalid header format
- `INVALID_STATE` - Parser in invalid state
- `UNKNOWN` - Unknown error

## Testing

Run the comprehensive test suite:

```bash
# From repository root
cd binding/lua
make test

# Or run all tests directly
cd binding/lua/tests
luajit run_all_tests.lua

# Or run individual test suites
cd binding/lua/tests
luajit test_core.lua          # Low-level parser tests
luajit test_state.lua          # State management tests
luajit test_streaming.lua      # Streaming parser tests
luajit test_multipart.lua      # High-level parse() tests
luajit test_build.lua          # High-level build() tests
luajit test_large_data.lua     # Large data handling tests
```

The test suite covers:
- Core functionality (parser creation, callbacks, simple parse)
- High-level parse() and build() functions with round-trip tests
- Memory management (limits, cleanup, error handling)
- Streaming support (chunked processing, pause/resume)
- Large data handling (4GB simulation, performance)
- Binary data and UTF-8 content
- Edge cases and error handling
- Nested multipart/mixed messages
- Special characters in field names, filenames, and values

### Large Data Test (4GB Simulation)

To test processing large amounts of data (simulating >4GB) without actually creating large files:

```bash
cd binding/lua/tests
luajit test_large_data.lua
```

This test:
- Simulates processing 4GB of data in 64KB chunks (65,536 chunks)
- Forces garbage collection during processing to test memory safety
- Verifies that the data pointer remains valid across GC cycles

**Note**: This test is particularly important for verifying that `lua_pcall` in callbacks doesn't trigger GC issues that could invalidate the data pointer during `multipart_parser_execute`.

## Performance

The binding has minimal overhead over the C library:

- Zero-copy for callbacks (data passed directly from C)
- Efficient memory management with proper cleanup
- Compatible with LuaJIT for maximum performance

## License

MIT License - Same as multipart-parser-c

## See Also

- [Main README](../../README.md) - C library documentation
- [Tests](./tests/README.md) - Test suite documentation
- [Examples](./examples/README.md) - Usage examples

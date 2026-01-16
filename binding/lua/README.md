# Lua Binding for multipart-parser-c

A complete Lua/LuaJIT binding for the multipart-parser-c library, providing a simple and efficient way to parse multipart/form-data in Lua applications.

## Features

- **Full API Coverage**: All parser functionality exposed to Lua
- **LuaJIT Compatible**: Optimized for LuaJIT 2.0+ (also works with Lua 5.1+)
- **Two APIs**: Simple parse() function and advanced streaming parser
- **Stream Processing**: Parse multipart data in chunks without buffering entire content
- **Callback-based**: Efficient event-driven parsing
- **Binary Safe**: Handles binary data (NULL bytes, high bytes) correctly
- **UTF-8 Support**: Properly handles UTF-8 encoded content
- **Error Handling**: Comprehensive error codes and messages
- **High Performance**: Zero-copy data passing, minimal overhead

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

There are two ways to use this binding:

### 1. Simple Parse Function (Recommended for most use cases)

The `parse()` function provides a simple, efficient interface that parses the entire multipart message and returns a Lua table:

```lua
local mp = require("multipart_parser")

local boundary = "boundary"
local body = [[--boundary
Content-Disposition: form-data; name="field1"

value1
--boundary
Content-Disposition: form-data; name="field2"
Content-Type: text/plain

value2
--boundary--]]

-- Parse and get result as table
local result = mp.parse(boundary, body)

if result then
    -- result is an array of parts
    for i, part in ipairs(result) do
        print("Part " .. i .. ":")

        -- Headers are stored as key-value pairs
        for k, v in pairs(part) do
            if type(k) == "string" then
                print("  Header: " .. k .. " = " .. v)
            end
        end

        -- Data chunks are stored in array part
        for j, chunk in ipairs(part) do
            print("  Data: " .. chunk)
        end
    end
else
    print("Parse failed")
end
```

**Output format:**
```lua
{
    [1] = {  -- First part
        ["Content-Disposition"] = "form-data; name=\"field1\"",
        [1] = "value1"  -- Data chunks
    },
    [2] = {  -- Second part
        ["Content-Disposition"] = "form-data; name=\"field2\"",
        ["Content-Type"] = "text/plain",
        [1] = "value2"
    }
}
```

**Error handling:**
```lua
local result, err = mp.parse(boundary, body)
if not result then
    print("Parse error: " .. err)
end
```

### 2. Advanced Streaming Parser (For custom processing)

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

### Module Functions

#### `mp.parse(boundary, body)`

**Simple parse function** - Parses entire multipart message and returns table structure.

**Parameters:**
- `boundary` (string): The boundary string (without "--" prefix)
- `body` (string): The complete multipart message body

**Returns:**
- On success: Table containing parsed parts (see structure below)
- On error: `nil, error_message`

**Result Structure:**
```lua
{
    [1] = {  -- First part (array index)
        ["Header-Name"] = "header-value",  -- Headers as key-value pairs
        [1] = "data chunk 1",  -- Data chunks as array elements
        [2] = "data chunk 2",
        ...
    },
    [2] = {  -- Second part
        ...
    }
}
```

**Example:**
```lua
local result, err = mp.parse("boundary", body)
if result then
    for i, part in ipairs(result) do
        -- Access headers
        local content_type = part["Content-Type"]

        -- Access data chunks
        for j, chunk in ipairs(part) do
            print(chunk)
        end
    end
else
    print("Error: " .. err)
end
```

**Performance Notes:**
- Very efficient - directly builds result table on Lua stack
- No intermediate allocations or copies
- Suitable for most use cases where entire message is available
- Memory efficient - data is not buffered in C

#### `mp.new(boundary, [callbacks])`

**Advanced streaming parser** - Create a parser with custom callbacks for fine-grained control.

**Parameters:**
- `boundary` (string): The boundary string (without "--" prefix)
- `callbacks` (table, optional): Table of callback functions

**Returns:**
- Parser object or raises error on failure

**Example:**
```lua
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

# Or run directly
luajit test.lua
```

The test suite includes 15 comprehensive tests covering:
- Module loading
- Basic parsing
- Multi-part messages
- Chunked parsing
- Binary data handling
- UTF-8 content
- Error handling
- Edge cases

## Performance

The binding has minimal overhead over the C library:

- Zero-copy for callbacks (data passed directly from C)
- Efficient memory management with proper cleanup
- Compatible with LuaJIT for maximum performance

## License

MIT License - Same as multipart-parser-c

## See Also

- [Main README](../../README.md) - C library documentation
- [test.lua](./test.lua) - Comprehensive test examples

# Multipart Parser Lua Binding Examples

This directory contains practical examples demonstrating how to use the multipart-parser Lua binding.

## Examples

### 1. basic_usage.lua
Basic multipart parsing example showing fundamental usage patterns.

**Features demonstrated:**
- Creating a parser with callbacks
- Handling multipart data
- Processing headers and data
- Basic error handling

**Usage:**
```bash
cd examples
luajit basic_usage.lua
```

### 2. streaming_usage.lua
Advanced streaming examples for real-world scenarios.

**Features demonstrated:**
- Streaming data processing with `feed()` method
- Pause and resume functionality
- Progress monitoring
- Network stream simulation
- Memory limits in streaming context
- Error handling in streams

**Usage:**
```bash
cd examples
luajit streaming_usage.lua
```

## Common Use Cases

### Web Server Integration
```lua
local mp = require("multipart_parser")

-- In your request handler
local parser = mp.new(boundary, {
  on_header_field = function(name) 
    -- Store header name
  end,
  on_header_value = function(value)
    -- Store header value
  end,
  on_part_data = function(data)
    -- Process part data (e.g., write to file)
    return 0
  end
})

-- Feed request body in chunks
for chunk in request_body_iterator() do
  parser:feed(chunk)
end
```

### File Upload Handler
```lua
local files = {}
local current_file = nil

local callbacks = {
  on_part_data_begin = function()
    current_file = {headers = {}, data = {}}
  end,
  
  on_header_field = function(name)
    current_header_name = name
  end,
  
  on_header_value = function(value)
    current_file.headers[current_header_name] = value
  end,
  
  on_part_data = function(data)
    table.insert(current_file.data, data)
    return 0
  end,
  
  on_part_data_end = function()
    table.insert(files, current_file)
  end
}

local parser = mp.new(boundary, callbacks)
parser:execute(body)
```

## Advanced Features

### Error Handling
```lua
parser:execute(data)

-- Check for Lua callback errors
local lua_error = parser:get_last_lua_error()
if lua_error then
  print("Callback error:", lua_error)
end

-- Check parser errors
local err = parser:get_error()
if err ~= mp.ERROR.OK then
  print("Parser error:", parser:get_error_message())
end
```

## Requirements

- LuaJIT 2.0+ or Lua 5.1+
- Built multipart_parser.so module in parent directory

## See Also

- [Tests README](../tests/README.md) - Comprehensive test examples
- [API Documentation](../README.md) - Complete API reference

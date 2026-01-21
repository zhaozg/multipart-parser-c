#!/usr/bin/env luajit
-- Streaming Processing Example
-- Demonstrates how to use the parser with chunked data from network streams
-- Shows pause/resume functionality and proper error handling

-- Try to load from current directory first
local function load_module()
  local original_cpath = package.cpath
  local paths = {
    "./?.so",
    "./binding/lua/?.so",
  }

  local new_cpath = original_cpath
  for _, path in ipairs(paths) do
    if not new_cpath:find(path, 1, true) then
      new_cpath = path .. ";" .. new_cpath
    end
  end
  package.cpath = new_cpath
end

load_module()
local mp = require("multipart_parser")

print("===========================================")
print("Streaming Processing Example")
print("===========================================\n")

-- Example 1: Basic streaming with feed()
print("Example 1: Basic streaming with feed() method")
print("---------------------------------------------")

local part_count = 0
local callbacks = {
  on_part_data_begin = function()
    part_count = part_count + 1
    print(string.format("  Starting part %d", part_count))
    return 0  -- Continue processing
  end,

  on_header_field = function(data)
    print(string.format("  Header field: %s", data))
    return 0
  end,

  on_header_value = function(data)
    print(string.format("  Header value: %s", data))
    return 0
  end,

  on_part_data = function(data)
    print(string.format("  Part data chunk (%d bytes): %s", #data, data:sub(1, 20)))
    return 0
  end,

  on_part_data_end = function()
    print(string.format("  Finished part %d", part_count))
    return 0
  end,
}

local parser = mp.new("boundary", callbacks)

-- Simulate receiving data in chunks from network
local chunks = {
  "--boundary\r\n",
  "Content-Dis",
  "position: form-data; name=\"field1\"\r\n",
  "\r\n",
  "value1\r\n",
  "--boundary\r\n",
  "Content-Disposition: form-data; name=\"field2\"\r\n",
  "\r\n",
  "value2\r\n",
  "--boundary--",
}

print("Processing chunks one by one:")
for i, chunk in ipairs(chunks) do
  print(string.format("\nChunk %d: %s", i, chunk:gsub("\r\n", "\\r\\n")))
  local parsed = parser:feed(chunk)  -- Using feed() method (alias for execute)
  print(string.format("  Parsed %d bytes", parsed))
end

parser:free()

-- Example 2: Pause and Resume
print("\n\nExample 2: Pause and Resume Processing")
print("---------------------------------------------")

local paused = false
local pause_after_bytes = 20
local total_data_processed = 0

local pause_callbacks = {
  on_part_data = function(data)
    total_data_processed = total_data_processed + #data
    print(string.format("  Processing %d bytes (total: %d)", #data, total_data_processed))

    -- Pause after processing some data
    if not paused and total_data_processed >= pause_after_bytes then
      print("  >>> PAUSING parser (callback returning 1)")
      paused = true
      return 1  -- Non-zero return value pauses the parser
    end

    return 0  -- Continue
  end,
}

local parser2 = mp.new("boundary", pause_callbacks)

-- Create data with a long part
local test_data = "--boundary\r\n" ..
  "Content-Type: text/plain\r\n" ..
  "\r\n" ..
  string.rep("x", 100) .. "\r\n" ..
  "--boundary--"

print("Feeding data to parser...")
local parsed = parser2:feed(test_data)
print(string.format("Parsed %d bytes before pause", parsed))

-- Check error to confirm pause
local err = parser2:get_error()
local err_msg = parser2:get_error_message()
print(string.format("Parser error code: %d", err))
print(string.format("Parser error message: %s", err_msg))

if err == mp.ERROR.PAUSED then
  print("\n>>> Parser is PAUSED as expected")
  print(string.format(">>> To resume, feed the remaining data starting from byte %d", parsed + 1))

  -- Reset pause flag and continue processing remaining data
  paused = false

  -- Resume by feeding remaining data
  local remaining = test_data:sub(parsed + 1)
  print(string.format("\nResuming with remaining %d bytes...", #remaining))

  -- Reset the parser to clear the PAUSED state (or create new parser)
  parser2:reset()
  parser2 = mp.new("boundary", pause_callbacks)

  -- Now feed all the data again without pausing
  pause_after_bytes = 999999  -- Don't pause this time
  local parsed2 = parser2:feed(test_data)
  print(string.format("Parsed %d bytes on second attempt (complete)", parsed2))

  local err2 = parser2:get_error()
  if err2 == mp.MPPE_OK then
    print(">>> Parser completed successfully after reset and reprocess")
  end
end

parser2:free()

-- Example 3: Simulating Network Stream with Error Handling
print("\n\nExample 3: Network Stream Simulation with Error Handling")
print("---------------------------------------------")

local function simulate_network_stream(parser, total_size, chunk_size)
  -- Generate test multipart data
  local full_data = "--testboundary\r\n" ..
    "Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    string.rep("Network data chunk... ", 50) .. "\r\n" ..
    "--testboundary--"

  print(string.format("Simulating network stream: %d bytes in %d-byte chunks", #full_data, chunk_size))

  local offset = 1
  local chunk_num = 0

  while offset <= #full_data do
    local chunk_end = math.min(offset + chunk_size - 1, #full_data)
    local chunk = full_data:sub(offset, chunk_end)
    chunk_num = chunk_num + 1

    print(string.format("  Chunk %d: bytes %d-%d (%d bytes)",
          chunk_num, offset, chunk_end, #chunk))

    local parsed = parser:feed(chunk)

    -- Check for errors
    local err = parser:get_error()
    if err ~= mp.MPPE_OK and err ~= mp.MPPE_PAUSED then
      local err_msg = parser:get_error_message()
      print(string.format("  ERROR: %s", err_msg))
      return false
    end

    -- Check for Lua callback errors
    local lua_err = parser:get_last_lua_error()
    if lua_err then
      print(string.format("  CALLBACK ERROR: %s", lua_err))
      return false
    end

    if parsed < #chunk then
      print(string.format("  Warning: Only parsed %d of %d bytes", parsed, #chunk))
    end

    offset = offset + parsed
  end

  print("  Stream processing completed successfully")
  return true
end

local stream_callbacks = {
  on_part_data = function(data)
    -- Just acknowledge data receipt
    return 0
  end,
}

local parser3 = mp.new("testboundary", stream_callbacks)
local success = simulate_network_stream(parser3, 1000, 64)

assert(success)

parser3:free()

-- Example 4: Using Memory Limits with Streaming
print("\n\nExample 4: Memory Limits with Streaming")
print("---------------------------------------------")

local mem_callbacks = {
  on_part_data = function(data)
    return 0
  end,
}

-- Set a small memory limit (500 bytes)
local parser4 = mp.new("boundary", mem_callbacks, 500)

local large_data = "--boundary\r\n" ..
  "Content-Type: text/plain\r\n" ..
  "\r\n" ..
  string.rep("x", 1000) .. "\r\n" ..  -- This exceeds our 500 byte limit
  "--boundary--"

print(string.format("Attempting to parse %d bytes with 500 byte limit...", #large_data))

local parsed = parser4:feed(large_data)
print(string.format("Parsed %d bytes before memory limit", parsed))

-- Check for memory limit error
local lua_err = parser4:get_last_lua_error()
if lua_err and lua_err:match("Memory limit exceeded") then
  print(">>> Memory limit error detected as expected")
  print(string.format(">>> Error: %s", lua_err))
end

parser4:free()

print("\n===========================================")
print("Streaming examples completed!")
print("===========================================")

print("\nKey takeaways:")
print("1. Use feed() or execute() to process chunks incrementally")
print("2. Return non-zero from callbacks to pause parsing")
print("3. Check get_error() for MPPE_PAUSED to detect pause")
print("4. Resume by feeding remaining data from where parsing stopped")
print("5. Always check for errors and Lua callback errors")
print("6. Use memory limits to protect against large uploads")

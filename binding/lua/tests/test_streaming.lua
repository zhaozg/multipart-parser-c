#!/usr/bin/env luajit
-- Test suite for streaming/feed support

-- Try to load from current directory first, then system paths
package.cpath = package.cpath .. ";../?.so"

local mp = require("multipart_parser")

-- Test results tracking
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- Helper functions
local function test_start(name)
  tests_run = tests_run + 1
  io.write(string.format("Test %d: %s ... ", tests_run, name))
  io.flush()
end

local function test_pass()
  io.write("PASSED\n")
  tests_passed = tests_passed + 1
end

local function test_fail(msg)
  io.write(string.format("FAILED: %s\n", msg))
  tests_failed = tests_failed + 1
end

--- simple
-- Test 1: Basic parse still works without progress callback
local function test_basic_parse()
  test_start("Basic parse without progress callback")

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Test data\r\n" ..
    "--boundary--"

  local result = mp.parse("boundary", data)

  if not result then
    test_fail("Parse returned nil")
    return
  end

  if #result ~= 1 then
    test_fail(string.format("Expected 1 part, got %d", #result))
    return
  end

  test_pass()
end

-- Test 2: Progress callback is called
local function test_progress_callback()
  test_start("Progress callback is called")

  local calls = 0
  local last_parsed = 0
  local last_total = 0
  local last_percent = 0

  local function progress(parsed, total, percent)
    calls = calls + 1
    last_parsed = parsed
    last_total = total
    last_percent = percent
    return 0  -- Continue
  end

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    string.rep("x", 100) .. "\r\n" ..
    "--boundary--"

  local result = mp.parse("boundary", data, progress)

  if not result then
    test_fail("Parse returned nil")
    return
  end

  if calls == 0 then
    test_fail("Progress callback was never called")
    return
  end

  if last_total == 0 then
    test_fail("Total size was 0")
    return
  end

  if last_percent < 0 or last_percent > 100 then
    test_fail(string.format("Invalid percent: %f", last_percent))
    return
  end

  test_pass()
end

-- Test 3: Progress callback receives correct parameters
local function test_progress_parameters()
  test_start("Progress callback receives correct parameters")

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Data\r\n" ..
    "--boundary--"

  local total_size = #data
  local max_parsed = 0

  local function progress(parsed, total, percent)
    if total ~= total_size then
      error(string.format("Total mismatch: expected %d, got %d", total_size, total))
    end

    if parsed > total then
      error(string.format("Parsed > total: %d > %d", parsed, total))
    end

    if parsed > max_parsed then
      max_parsed = parsed
    end

    return 0
  end

  local result, err = mp.parse("boundary", data, progress)

  if not result then
    test_fail("Parse failed: " .. tostring(err))
    return
  end

  if max_parsed == 0 then
    test_fail("Progress callback never saw data")
    return
  end

  test_pass()
end

-- Test 4: Interrupt parsing with progress callback
local function test_interrupt_parsing()
  test_start("Interrupt parsing via progress callback")

  local stop_after = 50
  local total_parsed = 0

  local function progress(parsed, total, percent)
    total_parsed = parsed
    if parsed >= stop_after then
      return 1  -- Stop parsing
    end
    return 0
  end

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    string.rep("x", 200) .. "\r\n" ..
    "--boundary--"

  local result, err, status = mp.parse("boundary", data, progress)

  if result then
    test_fail("Parse should have been interrupted")
    return
  end

  if status ~= "interrupted" then
    test_fail("Expected 'interrupted' status, got: " .. tostring(status))
    return
  end

  if not err or not err:match("interrupted") then
    test_fail("Expected interruption error message")
    return
  end

  test_pass()
end

-- Test 5: Multiple parts with progress tracking
local function test_multiple_parts_progress()
  test_start("Multiple parts with progress tracking")

  local progress_calls = 0
  local increasing = true
  local last_parsed = 0

  local function progress(parsed, total, percent)
    progress_calls = progress_calls + 1
    if parsed < last_parsed then
      increasing = false
    end
    last_parsed = parsed
    return 0
  end

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Part1\r\n" ..
    "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Part2\r\n" ..
    "--boundary--"

  local result = mp.parse("boundary", data, progress)

  if not result then
    test_fail("Parse failed")
    return
  end

  if #result ~= 2 then
    test_fail(string.format("Expected 2 parts, got %d", #result))
    return
  end

  if progress_calls == 0 then
    test_fail("Progress callback never called")
    return
  end

  if not increasing then
    test_fail("Parsed bytes did not increase monotonically")
    return
  end

  test_pass()
end

-- Test 6: Error in progress callback stops parsing
local function test_progress_error()
  test_start("Error in progress callback stops parsing")

  local function progress(parsed, total, percent)
    if parsed > 20 then
      error("Test error")
    end
    return 0
  end

  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    string.rep("x", 100) .. "\r\n" ..
    "--boundary--"

  local result, err, status = mp.parse("boundary", data, progress)

  if result then
    test_fail("Parse should have failed due to error")
    return
  end

  -- Should be interrupted due to error
  if status ~= "interrupted" then
    test_fail("Expected 'interrupted' status")
    return
  end

  test_pass()
end

-- Test 7: Parse returns complete part info (headers + data)
local function test_complete_part_info()
  test_start("Parse returns complete part information")

  local data = "--boundary\r\n" ..
    "Content-Disposition: form-data; name=\"field1\"\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "value1\r\n" ..
    "--boundary--"

  local result = mp.parse("boundary", data)

  if not result or #result ~= 1 then
    test_fail("Expected 1 part")
    return
  end

  local part = result[1]

  -- Check headers are present
  if not part["Content-Disposition"] then
    test_fail("Missing Content-Disposition header")
    return
  end

  if not part["Content-Type"] then
    test_fail("Missing Content-Type header")
    return
  end

  -- Check data is present
  local data_found = false
  for i = 1, #part do
    if part[i] then
      data_found = true
      break
    end
  end

  if not data_found then
    test_fail("No data found in part")
    return
  end

  test_pass()
end

-- Test 8: Large data with progress monitoring
local function test_large_data_progress()
  test_start("Large data with progress monitoring")

  local progress_updates = {}

  local function progress(parsed, total, percent)
    table.insert(progress_updates, {parsed=parsed, total=total, percent=percent})
    return 0
  end

  local large_content = string.rep("Large data content... ", 500)
  local data = "--boundary\r\n" ..
    "Content-Type: application/octet-stream\r\n" ..
    "\r\n" ..
    large_content .. "\r\n" ..
    "--boundary--"

  local result = mp.parse("boundary", data, progress)

  if not result then
    test_fail("Parse failed")
    return
  end

  if #progress_updates == 0 then
    test_fail("No progress updates")
    return
  end

  -- Check progress is increasing
  for i = 2, #progress_updates do
    if progress_updates[i].parsed < progress_updates[i-1].parsed then
      test_fail("Progress did not increase")
      return
    end
  end

  test_pass()
end

--- streaming

-- Test 1: feed() method exists
local function test_feed_method_exists()
  test_start("feed() method exists")

  local parser = mp.new("boundary")

  if not parser.feed then
    test_fail("feed() method not found")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 2: feed() works like execute()
local function test_feed_works()
  test_start("feed() processes data correctly")

  local data_received = {}
  local callbacks = {
    on_part_data = function(data)
      table.insert(data_received, data)
      return 0
    end,
  }

  local parser = mp.new("boundary", callbacks)

  local test_data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Hello World\r\n" ..
    "--boundary--"

  local parsed = parser:feed(test_data)

  if parsed ~= #test_data then
    test_fail(string.format("Expected to parse %d bytes, got %d", #test_data, parsed))
    parser:free()
    return
  end

  if #data_received == 0 then
    test_fail("No data received through callback")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 3: Chunked feeding
local function test_chunked_feeding()
  test_start("Chunked feeding works")

  local chunks_received = 0
  local callbacks = {
    on_part_data = function(data)
      chunks_received = chunks_received + 1
      return 0
    end,
  }

  local parser = mp.new("boundary", callbacks)

  -- Feed data in small chunks
  local chunks = {
    "--boundary\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "Test",
    " Data",
    "\r\n",
    "--boundary--",
  }

  local total_parsed = 0
  for _, chunk in ipairs(chunks) do
    local parsed = parser:feed(chunk)
    total_parsed = total_parsed + parsed
  end

  if chunks_received == 0 then
    test_fail("No chunks received")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 4: Pause functionality
local function test_pause()
  test_start("Pause functionality")

  local should_pause = false
  local pause_count = 0

  local callbacks = {
    on_part_data = function(data)
      if should_pause then
        pause_count = pause_count + 1
        return 1  -- Pause
      end
      return 0
    end,
  }

  local parser = mp.new("boundary", callbacks)

  local test_data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    string.rep("x", 100) .. "\r\n" ..
    "--boundary--"

  -- First feed without pause
  should_pause = false
  local parsed1 = parser:feed(test_data)

  if parsed1 ~= #test_data then
    test_fail(string.format("Expected to parse all %d bytes without pause, got %d", #test_data, parsed1))
    parser:free()
    return
  end

  -- Reset and try with pause
  parser:reset()
  should_pause = true
  local parsed2 = parser:feed(test_data)

  if parsed2 >= #test_data then
    test_fail("Expected parser to pause before completing")
    parser:free()
    return
  end

  -- Check error is PAUSED
  local err = parser:get_error()
  if err ~= mp.ERROR.PAUSED then
    test_fail(string.format("Expected PAUSED (%d), got %d", mp.ERROR.PAUSED, err))
    parser:free()
    return
  end

  if pause_count == 0 then
    test_fail("Pause callback was never called")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 5: Multiple feeds build up data
local function test_incremental_parsing()
  test_start("Incremental parsing accumulates correctly")

  local total_data = ""
  local headers, header = {}, {}
  local key, cur
  local callbacks = {
    on_part_data_begin = function()
      header = {}
    end,

    on_header_field = function(data)
      key = key and key .. data or data
      cur = key
      return 0
    end,

    on_header_value = function(data)
      key = nil
      header[cur] = header[cur] and header[cur]..data or data
      return 0
    end,

    on_headers_complete = function()
      headers[#headers + 1] = header
      return 0
    end,

    on_part_data = function(data)
      total_data = total_data .. data
      return 0
    end,

    on_part_data_end = function()
      return 0
    end,

    on_body_end = function()
      return 0
    end,
  }

  local parser = mp.new("boundary", callbacks)

  -- Build multipart data incrementally
  parser:feed("--boundary\r\n")
  parser:feed("Content")
  parser:feed("-Type: text/")
  parser:feed("plain\r\n")
  parser:feed("\r\n")
  parser:feed("Part")
  parser:feed(" One")
  parser:feed("\r\n--boundary\r\n")
  parser:feed("Content-Type: text/")
  parser:feed("plain")
  parser:feed("\r\n")
  parser:feed("\r\n")
  parser:feed("Part Two")
  parser:feed("\r\n--boundary--")

  -- Should have received both parts
  if not total_data:find("Part One") then
    test_fail("First part not found")
    parser:free()
    return
  end

  if not total_data:find("Part Two") then
    test_fail("Second part not found")
    parser:free()
    return
  end

  if #headers ~=2 then
    test_fail(string.format("Expected 2 headers, got %d", #headers))
    parser:free()
    return
  end
  print(require('inspect')(headers))
  if headers[1]["Content-Type"] ~= "text/plain" then
    test_fail("First header Content-Type incorrect")
    print(" Expected: text/plain")
    print("  But got: " .. headers[1]["Content-Type"])
    parser:free()
    return
  end
  if headers[2]["Content-Type"] ~= "text/plain" then
    test_fail("Second header Content-Type incorrect")
    print(" Expected: text/plain")
    print("  But got: " .. headers[2]["Content-Type"])
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 6: feed() and execute() are equivalent
local function test_feed_execute_equivalent()
  test_start("feed() and execute() are equivalent")

  local data1 = {}
  local data2 = {}

  local callbacks1 = {
    on_part_data = function(data)
      table.insert(data1, data)
      return 0
    end,
  }

  local callbacks2 = {
    on_part_data = function(data)
      table.insert(data2, data)
      return 0
    end,
  }

  local test_data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Same Data\r\n" ..
    "--boundary--"

  local parser1 = mp.new("boundary", callbacks1)
  local parser2 = mp.new("boundary", callbacks2)

  local parsed1 = parser1:execute(test_data)
  local parsed2 = parser2:feed(test_data)

  if parsed1 ~= parsed2 then
    test_fail(string.format("execute parsed %d, feed parsed %d", parsed1, parsed2))
    parser1:free()
    parser2:free()
    return
  end

  if #data1 ~= #data2 then
    test_fail("Different number of callbacks")
    parser1:free()
    parser2:free()
    return
  end

  parser1:free()
  parser2:free()
  test_pass()
end

-- Test 7: Streaming with memory limit
local function test_streaming_memory_limit()
  test_start("Streaming respects memory limits")

  local callbacks = {
    on_part_data = function(data) return 0 end,
  }

  -- Small memory limit
  local parser = mp.new("boundary", callbacks, 100)

  -- Feed data that exceeds limit in chunks
  local chunk1 = "--boundary\r\nContent-Type: text/plain\r\n\r\n"
  local chunk2 = string.rep("x", 50)
  local chunk3 = string.rep("x", 60)  -- This should trigger limit (total > 100)

  parser:feed(chunk1)
  parser:feed(chunk2)
  parser:feed(chunk3)  -- Should fail here

  local err = parser:get_last_lua_error()
  if err then
    test_fail("Expected memory limit error")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 8: Error handling in streaming
local function test_streaming_error_handling()
  test_start("Error handling in streaming mode")

  local callbacks = {
    on_part_data = function(data)
      error("Callback error")
    end,
  }

  local parser = mp.new("boundary", callbacks)

  local test_data = "--boundary\r\n\r\ndata\r\n--boundary--"

  parser:feed(test_data)

  local err = parser:get_last_lua_error()
  if not err then
    test_fail("Expected Lua error to be captured")
    parser:free()
    return
  end

  if not err:match("Callback error") then
    test_fail("Error message incorrect: " .. err)
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("Simple and Streaming Test Suite")
  print("Testing feed() and pause/resume")
  print("==========================================")
  print()

  -- Run all tests
  test_basic_parse()
  test_progress_callback()
  test_progress_parameters()
  test_interrupt_parsing()
  test_multiple_parts_progress()
  test_progress_error()
  test_complete_part_info()
  test_large_data_progress()

  test_feed_method_exists()
  test_feed_works()
  test_chunked_feeding()
  test_pause()
  test_incremental_parsing()
  test_feed_execute_equivalent()
  test_streaming_memory_limit()
  test_streaming_error_handling()

  -- Print summary
  print()
  print("===========================================")
  print(string.format("Tests run: %d", tests_run))
  print(string.format("Tests passed: %d", tests_passed))
  print(string.format("Tests failed: %d", tests_failed))
  print("===========================================")

  -- Exit with appropriate code
  if tests_failed > 0 then
    print("\nSome tests failed!")
    os.exit(1)
  else
    print("\nAll tests passed!")
    os.exit(0)
  end
end

-- Run the tests
run_all_tests()

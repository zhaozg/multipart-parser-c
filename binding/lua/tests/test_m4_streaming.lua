#!/usr/bin/env luajit
-- Test suite for M4 (streaming/feed support)

-- Try to load from current directory first, then system paths
local function load_module()
package.cpath = package.cpath .. ";../?.so"
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
  local callbacks = {
    on_part_data = function(data)
      total_data = total_data .. data
      return 0
    end,
  }

  local parser = mp.new("boundary", callbacks)

  -- Build multipart data incrementally
  parser:feed("--boundary\r\n")
  parser:feed("Content-Type: text/plain\r\n")
  parser:feed("\r\n")
  parser:feed("Part")
  parser:feed(" One")
  parser:feed("\r\n--boundary\r\n")
  parser:feed("Content-Type: text/plain\r\n")
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

  local stats = parser:get_stats()
  if stats.parts_count ~= 2 then
    test_fail(string.format("Expected 2 parts, got %d", stats.parts_count))
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
  if not err or not err:match("Memory limit exceeded") then
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
  print("M4 Streaming Test Suite")
  print("Testing feed() and pause/resume")
  print("===========================================")
  print()

  -- Run all tests
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

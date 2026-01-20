#!/usr/bin/env luajit
-- Test suite for M1 (memory limits) and M2 (statistics)

-- Try to load from current directory first, then system paths
local function load_module()
package.cpath = package.cpath .. ";../?.so"
  local paths = {
    "./?.so",  -- Current directory
    "./binding/lua/?.so",  -- From repository root
  }
  
  -- Prepend our paths to the original cpath (avoiding duplicates)
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

-- Test 1: get_stats method exists
local function test_stats_method_exists()
  test_start("get_stats method exists")
  
  local parser = mp.new("boundary")
  
  if not parser.get_stats then
    test_fail("get_stats method not found")
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 2: Initial statistics are zero
local function test_initial_stats()
  test_start("Initial statistics are zero")
  
  local parser = mp.new("boundary")
  local stats = parser:get_stats()
  
  if stats.total_bytes ~= 0 then
    test_fail("total_bytes should be 0, got: " .. stats.total_bytes)
    parser:free()
    return
  end
  
  if stats.parts_count ~= 0 then
    test_fail("parts_count should be 0, got: " .. stats.parts_count)
    parser:free()
    return
  end
  
  if stats.max_part_size ~= 0 then
    test_fail("max_part_size should be 0, got: " .. stats.max_part_size)
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 3: Statistics updated after parsing
local function test_stats_updated()
  test_start("Statistics updated after parsing")
  
  local callbacks = {
    on_part_data = function(data) return 0 end,
  }
  
  local parser = mp.new("boundary", callbacks)
  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Hello World\r\n" ..
    "--boundary--"
  
  parser:execute(data)
  
  local stats = parser:get_stats()
  
  if stats.total_bytes == 0 then
    test_fail("total_bytes should be > 0")
    parser:free()
    return
  end
  
  if stats.parts_count ~= 1 then
    test_fail("parts_count should be 1, got: " .. stats.parts_count)
    parser:free()
    return
  end
  
  -- "Hello World" = 11 bytes
  if stats.max_part_size < 11 then
    test_fail("max_part_size should be >= 11, got: " .. stats.max_part_size)
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 4: Multiple parts statistics
local function test_multiple_parts_stats()
  test_start("Multiple parts statistics")
  
  local callbacks = {
    on_part_data = function(data) return 0 end,
  }
  
  local parser = mp.new("boundary", callbacks)
  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Part 1\r\n" ..
    "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Part 2 is longer\r\n" ..
    "--boundary--"
  
  parser:execute(data)
  
  local stats = parser:get_stats()
  
  if stats.parts_count ~= 2 then
    test_fail("parts_count should be 2, got: " .. stats.parts_count)
    parser:free()
    return
  end
  
  -- "Part 2 is longer" = 16 bytes, should be the max
  if stats.max_part_size < 16 then
    test_fail("max_part_size should be >= 16, got: " .. stats.max_part_size)
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 5: Stats reset on parser reset
local function test_stats_reset()
  test_start("Stats reset on parser reset")
  
  local callbacks = {
    on_part_data = function(data) return 0 end,
  }
  
  local parser = mp.new("boundary", callbacks)
  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Test data\r\n" ..
    "--boundary--"
  
  parser:execute(data)
  
  local stats1 = parser:get_stats()
  if stats1.total_bytes == 0 then
    test_fail("total_bytes should be > 0 before reset")
    parser:free()
    return
  end
  
  -- Reset parser
  parser:reset()
  
  local stats2 = parser:get_stats()
  if stats2.total_bytes ~= 0 then
    test_fail("total_bytes should be 0 after reset, got: " .. stats2.total_bytes)
    parser:free()
    return
  end
  
  if stats2.parts_count ~= 0 then
    test_fail("parts_count should be 0 after reset, got: " .. stats2.parts_count)
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 6: Memory limit parameter accepted
local function test_memory_limit_param()
  test_start("Memory limit parameter accepted")
  
  local max_mem = 1024 * 1024  -- 1MB
  local parser = mp.new("boundary", nil, max_mem)
  
  local stats = parser:get_stats()
  
  if stats.max_memory ~= max_mem then
    test_fail(string.format("max_memory should be %d, got: %d", max_mem, stats.max_memory))
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 7: Memory limit enforced
local function test_memory_limit_enforced()
  test_start("Memory limit enforced")
  
  local callbacks = {
    on_part_data = function(data) return 0 end,
  }
  
  -- Set very low memory limit (100 bytes)
  local parser = mp.new("boundary", callbacks, 100)
  
  -- Create data that exceeds limit
  local large_data = string.rep("x", 200)
  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    large_data .. "\r\n" ..
    "--boundary--"
  
  -- This should fail due to memory limit
  local parsed = parser:execute(data)
  
  -- Check if error was set
  local err = parser:get_last_lua_error()
  
  if not err or not err:match("Memory limit exceeded") then
    test_fail("Expected memory limit error")
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Test 8: Memory tracking without limit
local function test_memory_tracking_unlimited()
  test_start("Memory tracking without limit")
  
  local callbacks = {
    on_part_data = function(data) return 0 end,
  }
  
  -- No memory limit (default)
  local parser = mp.new("boundary", callbacks)
  
  local data = "--boundary\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Some data\r\n" ..
    "--boundary--"
  
  parser:execute(data)
  
  local stats = parser:get_stats()
  
  if stats.max_memory ~= 0 then
    test_fail("max_memory should be 0 (unlimited), got: " .. stats.max_memory)
    parser:free()
    return
  end
  
  -- current_memory should have some value
  if stats.current_memory == 0 then
    test_fail("current_memory should be tracked even without limit")
    parser:free()
    return
  end
  
  parser:free()
  test_pass()
end

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("M1 & M2 Test Suite")
  print("Testing Memory Limits and Statistics")
  print("===========================================")
  print()

  -- Run all tests
  test_stats_method_exists()
  test_initial_stats()
  test_stats_updated()
  test_multiple_parts_stats()
  test_stats_reset()
  test_memory_limit_param()
  test_memory_limit_enforced()
  test_memory_tracking_unlimited()

  -- Print summary
  print()
  print("===========================================")
  print(string.format("Tests run: %d", tests_run))
  print(string.format("Tests passed: %d", tests_passed))
  print(string.format("Tests failed: %d", tests_failed))
  print("===========================================")

  -- Exit with appropriate code
  if tests_failed > 0 then
    os.exit(1)
  else
    print("\nAll tests passed!")
    os.exit(0)
  end
end

-- Run the tests
run_all_tests()

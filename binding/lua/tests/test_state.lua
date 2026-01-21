#!/usr/bin/env luajit
-- Test suite for state management
-- Tests parser reset functionality and error handling

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

-- Test 1: Parser reset with new boundary
local function test_parser_reset()
  test_start("Parser reset with new boundary")

  local part_count1 = 0
  local part_count2 = 0

  local callbacks1 = {
    on_part_data_end = function()
      part_count1 = part_count1 + 1
      return 0
    end,
  }

  local callbacks2 = {
    on_part_data_end = function()
      part_count2 = part_count2 + 1
      return 0
    end,
  }

  local parser = mp.new("boundary1", callbacks1)
  local data1 = "--boundary1\r\n" .. "Content-Type: text/plain\r\n" .. "\r\n" .. "data1\r\n" .. "--boundary1--"

  -- Parse first data
  local parsed1 = parser:execute(data1)
  if parsed1 ~= #data1 then
    test_fail("First parse failed")
    parser:free()
    return
  end

  if part_count1 ~= 1 then
    test_fail("Expected 1 part in first parse")
    parser:free()
    return
  end

  -- Reset parser with new boundary
  local reset_ok = parser:reset("boundary2")
  if not reset_ok then
    test_fail("Reset failed")
    parser:free()
    return
  end

  -- Parse second data with new boundary
  local data2 = "--boundary2\r\n" .. "Content-Type: text/plain\r\n" .. "\r\n" .. "data2\r\n" .. "--boundary2--"

  local parsed2 = parser:execute(data2)
  if parsed2 ~= #data2 then
    test_fail("Second parse after reset failed")
    parser:free()
    return
  end

  -- Note: callbacks1 is still in use, so part_count1 will increment
  if part_count1 ~= 2 then
    test_fail("Expected 2 total parts after reset")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 2: Parser reset without changing boundary
local function test_parser_reset_same_boundary()
  test_start("Parser reset keeping same boundary")

  local part_count = 0

  local callbacks = {
    on_part_data_end = function()
      part_count = part_count + 1
      return 0
    end,
  }

  local parser = mp.new("bound", callbacks)
  local data = "--bound\r\n" .. "Content-Type: text/plain\r\n" .. "\r\n" .. "test\r\n" .. "--bound--"

  -- Parse first time
  local parsed1 = parser:execute(data)
  if parsed1 ~= #data then
    test_fail("First parse failed")
    parser:free()
    return
  end

  if part_count ~= 1 then
    test_fail("Expected 1 part in first parse")
    parser:free()
    return
  end

  -- Reset without changing boundary (pass nil)
  local reset_ok = parser:reset(nil)
  if not reset_ok then
    test_fail("Reset failed")
    parser:free()
    return
  end

  -- Parse second time
  local parsed2 = parser:execute(data)
  if parsed2 ~= #data then
    test_fail("Second parse after reset failed")
    parser:free()
    return
  end

  if part_count ~= 2 then
    test_fail("Expected 2 total parts after reset")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Test 3: Parser reset clears error state
local function test_parser_reset_clears_error()
  test_start("Parser reset clears error state")

  local parser = mp.new("bound")

  -- Parse bad data to trigger an error
  local bad_data = "--bound\r\nContent@Type: text/plain\r\n"
  parser:execute(bad_data)

  -- Should have an error
  local err = parser:get_error()
  if err == mp.ERROR.OK then
    test_fail("Should have error after bad data")
    parser:free()
    return
  end

  -- Reset parser
  local reset_ok = parser:reset(nil)
  if not reset_ok then
    test_fail("Reset failed")
    parser:free()
    return
  end

  -- Error should be cleared
  err = parser:get_error()
  if err ~= mp.ERROR.OK then
    test_fail("Error not cleared after reset")
    parser:free()
    return
  end

  -- Parse good data
  local good_data = "--bound\r\n" .. "Content-Type: text/plain\r\n" .. "\r\n" .. "data\r\n" .. "--bound--"

  local parsed = parser:execute(good_data)
  if parsed ~= #good_data then
    test_fail("Parse failed after reset")
    parser:free()
    return
  end

  parser:free()
  test_pass()
end

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("State Management Test Suite")
  print("===========================================")
  print()

  -- Parser reset tests
  test_parser_reset()
  test_parser_reset_same_boundary()
  test_parser_reset_clears_error()

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

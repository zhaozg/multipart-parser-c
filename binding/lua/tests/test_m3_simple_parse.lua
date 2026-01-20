#!/usr/bin/env luajit
-- Test suite for M3 (improved simple parse mode)

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

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("M3 Simple Parse Mode Test Suite")
  print("Testing progress callback and interruption")
  print("===========================================")
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

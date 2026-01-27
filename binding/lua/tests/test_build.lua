#!/usr/bin/env luajit
--- Test suite for multipart.build() function
-- Tests the build function that creates multipart/form-data from structured data

-- Add the binding directory to package.cpath and package.path
package.cpath = package.cpath .. ";../?.so"
package.path = package.path .. ";../?.lua"

local multipart = require("multipart")

-- Test results tracking
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- Helper function for deep equality
local function deep_equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then return false end
  end
  for k, v in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- Helper function to dump tables
local function dump(t, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  if type(t) ~= "table" then
    return tostring(t)
  end
  local result = "{\n"
  for k, v in pairs(t) do
    local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%d]", k)
    if type(v) == "table" then
      result = result .. prefix .. "  " .. key .. " = " .. dump(v, indent + 1) .. ",\n"
    else
      local value = type(v) == "string" and string.format("%q", v) or tostring(v)
      result = result .. prefix .. "  " .. key .. " = " .. value .. ",\n"
    end
  end
  result = result .. prefix .. "}"
  return result
end

-- Test helpers
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

-- Test: Simple field
local function test_simple_field()
  test_start("simple field")
  local data = { field1 = "value1" }
  local body, content_type = multipart.build(data)

  -- Parse it back to verify
  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Multiple fields
local function test_multiple_fields()
  test_start("multiple fields")
  local data = {
    field1 = "value1",
    field2 = "value2",
    field3 = "value3"
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: File upload
local function test_file_upload()
  test_start("file upload")
  local data = {
    field1 = "text value",
    file = {
      [1] = "file content here",
      filename = "test.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Multiple files with same field name
local function test_repeated_field()
  test_start("repeated field")
  local data = {
    tags = { "tag1", "tag2", "tag3" }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Nested multipart (multipart/mixed)
local function test_nested_multipart()
  test_start("nested multipart (multipart/mixed)")
  local data = {
    description = "Multiple files",
    files = {
      { [1] = "content of file 1", filename = "file1.txt", ["Content-Type"] = "text/plain" },
      { [1] = "content of file 2", filename = "file2.txt", ["Content-Type"] = "text/plain" }
    }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Empty file
local function test_empty_file()
  test_start("empty file")
  local data = {
    field1 = "value",
    file = {
      [1] = "",
      filename = "empty.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Special characters in field names
local function test_special_chars_in_names()
  test_start("special characters in field names")
  local data = {
    ["field-name"] = "value",
    ["field_name"] = "another value"
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Special characters in values
local function test_special_chars_in_values()
  test_start("special characters in values")
  local data = {
    field1 = "value with\nnewlines\r\nand\ttabs",
    field2 = "quotes: \"quoted\" text"
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: UTF-8 content
local function test_utf8_content()
  test_start("UTF-8 content")
  local data = {
    field1 = "中文内容",
    field2 = "🎉 emoji",
    field3 = "Ελληνικά"
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Empty data
local function test_empty_data()
  test_start("empty data")
  local data = {}
  local body, content_type = multipart.build(data)

  -- Helper to escape pattern special characters for Lua pattern matching
  local function escape_pattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  end

  -- Should have closing boundary in body
  local boundary_match = content_type:match("boundary=([^;%s]+)")
  if not boundary_match then
    test_fail("No boundary in Content-Type")
    return
  end

  -- Check for closing boundary using plain string match
  if not body:find("--" .. boundary_match .. "--", 1, true) then
    test_fail("Missing closing boundary in body")
    return
  end

  -- Parse back should return empty table
  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed for empty data")
    return
  end
  test_pass()
end

-- Test: Custom boundary
local function test_custom_boundary()
  test_start("custom boundary")
  local data = { field = "value" }
  local custom_boundary = "MyCustomBoundary123"
  local body, content_type = multipart.build(data, custom_boundary)

  -- Check that custom boundary is used (using plain string find)
  if not content_type:find(custom_boundary, 1, true) then
    test_fail("Custom boundary not in Content-Type")
    return
  end

  if not body:find("--" .. custom_boundary, 1, true) then
    test_fail("Custom boundary not in body")
    return
  end

  -- Parse back
  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed with custom boundary")
    return
  end
  test_pass()
end

-- Test: Filename with special characters
local function test_filename_special_chars()
  test_start("filename with special characters")
  local data = {
    file = {
      [1] = "content",
      filename = "file with spaces.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Binary data
local function test_binary_data()
  test_start("binary data")
  local binary_content = string.char(0, 1, 2, 3, 255, 254, 253)
  local data = {
    file = {
      [1] = binary_content,
      filename = "binary.dat",
      ["Content-Type"] = "application/octet-stream"
    }
  }
  local body, content_type = multipart.build(data)

  local parsed = multipart.parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed for binary data")
    return
  end
  test_pass()
end

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("Multipart Build Function Tests")
  print("===========================================")
  print()

  -- Run all tests
  test_simple_field()
  test_multiple_fields()
  test_file_upload()
  test_repeated_field()
  test_nested_multipart()
  test_empty_file()
  test_special_chars_in_names()
  test_special_chars_in_values()
  test_utf8_content()
  test_empty_data()
  test_custom_boundary()
  test_filename_special_chars()
  test_binary_data()

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

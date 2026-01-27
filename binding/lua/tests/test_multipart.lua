#!/usr/bin/env luajit
--- Test suite for multipart parse and build functions
-- Tests both parsing and building of multipart/form-data messages

-- Add the binding directory to package.cpath and package.path
package.cpath = package.cpath .. ";../?.so"
package.path = package.path .. ";../?.lua"

local mp= require("multipart")
local parse = mp.parse
local build = mp.build

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

-- Test cases from original test-multipart.lua

local function test_suite_1()
  test_start("Content-type: multipart/form-data, boundary=AaB03x")
  local body = table.concat({
    "--AaB03x\r\n",
    "content-disposition: form-data; name=\"field1\"\r\n",
    "\r\n",
    "Joe Blow\r\n",
    "--AaB03x\r\n",
    "content-disposition: form-data; name=\"pics\"\r\n",
    "Content-type: multipart/mixed, boundary=BbC04y\r\n",
    "\r\n",
    "--BbC04y\r\n",
    "Content-disposition: attachment; filename=\"file1.txt\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "... contents of file1.txt ...\r\n",
    "--BbC04y\r\n",
    "Content-disposition: attachment; filename=\"file2.gif\"\r\n",
    "Content-type: image/gif\r\n",
    "Content-Transfer-Encoding: binary\r\n",
    "\r\n",
    "...contents of file2.gif...\r\n",
    "--BbC04y--\r\n",
    "--AaB03x--\r\n",
  })
  local expected = {
    pics = {
      { '... contents of file1.txt ...', filename = 'file1.txt', ['Content-Type'] = 'text/plain' },
      { '...contents of file2.gif...', filename = 'file2.gif', ['Content-type'] = 'image/gif', ['Content-Transfer-Encoding'] = 'binary' }
    },
    field1 = 'Joe Blow'
  }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=AaB03x")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_suite_2()
  test_start("Content-type: multipart/form-data, boundary=AaB03y")
  local body = table.concat({
    "--AaB03y\r\n",
    "content-disposition: form-data; name=\"field1\"\r\n",
    "\r\n",
    "Joe Blow\r\n",
    "--AaB03y\r\n",
    "content-disposition: form-data; name=\"pics\"; filename=\"file1.txt\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    " ... contents of file1.txt ...\r\n",
    "--AaB03y--\r\n",
  })
  local expected = {
    pics = {
      " ... contents of file1.txt ...",
      filename = "file1.txt",
      ["Content-Type"] = "text/plain",
    },
    field1 = "Joe Blow",
  }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=AaB03y")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_suite_3()
  test_start("multipart/form-data; boundary=----WebKitFormBoundary6bHnnUFIFpNjRCNi")
  local body = table.concat({
    "------WebKitFormBoundary6bHnnUFIFpNjRCNi\r\n",
    "Content-Disposition: form-data; name=\"field1\"\r\n",
    "\r\n",
    "\r\n",
    "------WebKitFormBoundary6bHnnUFIFpNjRCNi\r\n",
    "Content-Disposition: form-data; name=\"file\"; filename=\"\"\r\n",
    "Content-Type: application/octet-stream\r\n",
    "\r\n",
    "\r\n",
    "------WebKitFormBoundary6bHnnUFIFpNjRCNi--\r\n",
  })
  local expected = {
    file = {
      "",
      filename = "",
      ["Content-Type"] = "application/octet-stream",
    },
    field1 = "",
  }
  local ret = parse(body, "multipart/form-data; boundary=----WebKitFormBoundary6bHnnUFIFpNjRCNi")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_simple_field()
  test_start("simple field")
  local body = "--A\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--A--\r\n"
  local expected = { foo = "bar" }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=A")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_empty_body()
  test_start("empty body")
  local body = ""
  local expected = {}
  local ret = parse(body, "Content-type: multipart/form-data, boundary=EMPTY")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_missing_boundary_param()
  test_start("missing boundary param")
  local body = "--B\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--B--\r\n"
  local expected = { foo = "bar" }
  local ret = parse(body, "multipart/form-data; boundary=B")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_repeated_field()
  test_start("repeated field")
  local body = table.concat({
    "--R\r\n",
    "Content-Disposition: form-data; name=\"foo\"\r\n",
    "\r\n",
    "one\r\n",
    "--R\r\n",
    "Content-Disposition: form-data; name=\"foo\"\r\n",
    "\r\n",
    "two\r\n",
    "--R--\r\n",
  })
  local expected = { foo = { "one", "two" } }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=R")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_illegal_header()
  test_start("illegal header")
  local body = "--BAD\r\nContent-Disposition form-data; name=\"foo\"\r\n\r\nbar\r\n--BAD--\r\n"
  local expected = {}
  local ret = parse(body, "Content-type: multipart/form-data, boundary=BAD")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_only_boundary()
  test_start("only boundary, no parts")
  local body = "--ONLY--\r\n"
  local expected = {}
  local ret = parse(body, "Content-type: multipart/form-data, boundary=ONLY")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_boundary_in_content()
  test_start("content contains boundary-like string")
  local body = "--B\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nthis is not a boundary: --B\r\n--B--\r\n"
  local expected = { foo = "this is not a boundary: --B" }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=B")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_multiple_files()
  test_start("multiple files (nested multipart)")
  local body = table.concat({
    "--MultiFile\r\n",
    "Content-Disposition: form-data; name=\"desc\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "多个文件上传\r\n",
    "--MultiFile\r\n",
    "Content-Disposition: form-data; name=\"files\"\r\n",
    "Content-Type: multipart/mixed; boundary=InnerBoundary\r\n",
    "\r\n",
    "--InnerBoundary\r\n",
    "Content-Disposition: attachment; filename=\"a.txt\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "A内容\r\n",
    "--InnerBoundary\r\n",
    "Content-Disposition: attachment; filename=\"b.txt\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "B内容\r\n",
    "--InnerBoundary--\r\n",
    "--MultiFile--\r\n",
  })
  local expected = {
    desc = "多个文件上传",
    files = {
      { "A内容", filename = "a.txt", ["Content-Type"] = "text/plain" },
      { "B内容", filename = "b.txt", ["Content-Type"] = "text/plain" },
    },
  }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=MultiFile")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_no_name_part()
  test_start("no name part")
  local body = table.concat({
    "--NoName\r\n",
    "Content-Disposition: form-data; name=\"foo\"\r\n",
    "Content-Type: text/plain\r\n",
    "\r\n",
    "bar\r\n",
    "--NoName\r\n",
    "Content-Disposition: attachment; filename=\"x.png\"\r\n",
    "Content-Type: image/png\r\n",
    "\r\n",
    "PNGDATA\r\n",
    "--NoName--\r\n",
  })
  local expected = {
    foo = "bar",
    [1] = { "PNGDATA", filename = "x.png", ["Content-Type"] = "image/png" },
  }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=NoName")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

local function test_special_char_field()
  test_start("special char field")
  local body = table.concat({
    "--SpecialChar\r\n",
    "Content-Disposition: form-data; name=\"field-ü\"\r\n",
    "Content-Type: text/plain; charset=utf-8\r\n",
    "\r\n",
    "特殊字符内容\r\n",
    "--SpecialChar--\r\n",
  })
  local expected = { ["field-ü"] = "特殊字符内容" }
  local ret = parse(body, "Content-type: multipart/form-data, boundary=SpecialChar")
  if not deep_equal(expected, ret) then
    test_fail("Result mismatch\nExpected: " .. dump(expected) .. "\nGot: " .. dump(ret))
    return
  end
  test_pass()
end

-- ============================================
-- BUILD FUNCTION TESTS (Round-trip tests)
-- ============================================

-- Test: Build simple field
local function test_build_simple_field()
  test_start("build: simple field")
  local data = { field1 = "value1" }
  local body, content_type = build(data)

  -- Parse it back to verify
  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build multiple fields
local function test_build_multiple_fields()
  test_start("build: multiple fields")
  local data = {
    field1 = "value1",
    field2 = "value2",
    field3 = "value3"
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build file upload
local function test_build_file_upload()
  test_start("build: file upload")
  local data = {
    field1 = "text value",
    file = {
      [1] = "file content here",
      filename = "test.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build repeated field
local function test_build_repeated_field()
  test_start("build: repeated field")
  local data = {
    tags = { "tag1", "tag2", "tag3" }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build nested multipart (multipart/mixed)
local function test_build_nested_multipart()
  test_start("build: nested multipart (multipart/mixed)")
  local data = {
    description = "Multiple files",
    files = {
      { [1] = "content of file 1", filename = "file1.txt", ["Content-Type"] = "text/plain" },
      { [1] = "content of file 2", filename = "file2.txt", ["Content-Type"] = "text/plain" }
    }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build empty file
local function test_build_empty_file()
  test_start("build: empty file")
  local data = {
    field1 = "value",
    file = {
      [1] = "",
      filename = "empty.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build special characters in field names
local function test_build_special_chars_in_names()
  test_start("build: special characters in field names")
  local data = {
    ["field-name"] = "value",
    ["field_name"] = "another value"
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build special characters in values
local function test_build_special_chars_in_values()
  test_start("build: special characters in values")
  local data = {
    field1 = "value with\nnewlines\r\nand\ttabs",
    field2 = "quotes: \"quoted\" text"
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build UTF-8 content
local function test_build_utf8_content()
  test_start("build: UTF-8 content")
  local data = {
    field1 = "中文内容",
    field2 = "🎉 emoji",
    field3 = "Ελληνικά"
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build empty data
local function test_build_empty_data()
  test_start("build: empty data")
  local data = {}
  local body, content_type = build(data)

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
  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed for empty data")
    return
  end
  test_pass()
end

-- Test: Build custom boundary
local function test_build_custom_boundary()
  test_start("build: custom boundary")
  local data = { field = "value" }
  local custom_boundary = "MyCustomBoundary123"
  local body, content_type = build(data, custom_boundary)

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
  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed with custom boundary")
    return
  end
  test_pass()
end

-- Test: Build filename with special characters
local function test_build_filename_special_chars()
  test_start("build: filename with special characters")
  local data = {
    file = {
      [1] = "content",
      filename = "file with spaces.txt",
      ["Content-Type"] = "text/plain"
    }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed\nExpected: " .. dump(data) .. "\nGot: " .. dump(parsed))
    return
  end
  test_pass()
end

-- Test: Build binary data
local function test_build_binary_data()
  test_start("build: binary data")
  local binary_content = string.char(0, 1, 2, 3, 255, 254, 253)
  local data = {
    file = {
      [1] = binary_content,
      filename = "binary.dat",
      ["Content-Type"] = "application/octet-stream"
    }
  }
  local body, content_type = build(data)

  local parsed = parse(body, content_type)
  if not deep_equal(data, parsed) then
    test_fail("Round-trip failed for binary data")
    return
  end
  test_pass()
end

-- Main test execution
local function run_all_tests()
  print("===========================================")
  print("Multipart Parse and Build Function Tests")
  print("===========================================")
  print()

  -- Parse tests
  print("--- Parse Tests ---")
  test_suite_1()
  test_suite_2()
  test_suite_3()
  test_simple_field()
  test_empty_body()
  test_missing_boundary_param()
  test_repeated_field()
  test_illegal_header()
  test_only_boundary()
  test_boundary_in_content()
  test_multiple_files()
  test_no_name_part()
  test_special_char_field()

  -- Build tests
  print("\n--- Build Tests (Round-trip) ---")
  test_build_simple_field()
  test_build_multiple_fields()
  test_build_file_upload()
  test_build_repeated_field()
  test_build_nested_multipart()
  test_build_empty_file()
  test_build_special_chars_in_names()
  test_build_special_chars_in_values()
  test_build_utf8_content()
  test_build_empty_data()
  test_build_custom_boundary()
  test_build_filename_special_chars()
  test_build_binary_data()

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

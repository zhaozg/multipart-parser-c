#!/usr/bin/env luajit
-- Unified test runner for multipart-parser Lua binding
-- Runs all test suites in order and reports aggregate results

-- Module loading helper
local function load_module()
  local original_cpath = package.cpath
  local paths = {
    "./../?.so",
    "./?.so",
    "../?.so",
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

-- Test suite configuration
local test_suites = {
  {name = "Core Functionality", file = "test_core.lua"},
  {name = "State Management", file = "test_state.lua"},
  {name = "Streaming Support", file = "test_streaming.lua"},
  {name = "Large Data Handling", file = "test_large_data.lua"},
  {name = "Compatibility Layer", file = "test_multipart.lua"},
}

-- Results tracking
local total_suites = 0
local passed_suites = 0
local failed_suites = 0
local total_tests = 0
local total_passed = 0
local total_failed = 0

print(string.rep("=", 70))
print("Multipart Parser Lua Binding - Complete Test Suite")
print(string.rep("=", 70))
print()

-- Run each test suite
for _, suite in ipairs(test_suites) do
  total_suites = total_suites + 1

  print(string.format("Running: %s", suite.name))
  print(string.rep("-", 70))

  local cmd = string.format("luajit %s 2>&1", suite.file)
  local handle = io.popen(cmd)
  local output = handle:read("*a")
  local success = handle:close()

  -- Parse test results from output
  local tests_run = output:match("Tests run: (%d+)") or "?"
  local tests_passed = output:match("Tests passed: (%d+)") or "?"
  local tests_failed = output:match("Tests failed: (%d+)") or "?"

  if tests_run ~= "?" then
    total_tests = total_tests + tonumber(tests_run)
    total_passed = total_passed + tonumber(tests_passed)
    total_failed = total_failed + tonumber(tests_failed)
  end

  if success then
    passed_suites = passed_suites + 1
    print(string.format("✓ PASSED: %s tests passed, %s failed", tests_passed, tests_failed))
  else
    failed_suites = failed_suites + 1
    print(string.format("✗ FAILED: %s", suite.name))
    print("\nOutput:")
    print(output)
  end

  print()
end

-- Print summary
print(string.rep("=", 70))
print("Test Suite Summary")
print(string.rep("=", 70))
print(string.format("Suites run:    %d", total_suites))
print(string.format("Suites passed: %d", passed_suites))
print(string.format("Suites failed: %d", failed_suites))
print()
print(string.format("Total tests run:    %d", total_tests))
print(string.format("Total tests passed: %d", total_passed))
print(string.format("Total tests failed: %d", total_failed))
print(string.rep("=", 70))

-- Exit with appropriate code
if failed_suites > 0 or total_failed > 0 then
  print("\n✗ Some tests FAILED")
  os.exit(1)
else
  print("\n✓ All tests PASSED")
  os.exit(0)
end

#!/usr/bin/env luajit
--- Example: Building multipart/form-data messages
-- Demonstrates how to use the multipart.build() function
-- to create multipart/form-data for HTTP requests

-- Add the binding directory to package paths
package.cpath = package.cpath .. ";../?.so"
package.path = package.path .. ";../?.lua"

local multipart = require("multipart")

print("=================================================")
print("Multipart Build Examples")
print("=================================================\n")

-- Example 1: Simple form fields
print("Example 1: Simple form fields")
print("-------------------------------------------------")
local data1 = {
  username = "john_doe",
  email = "john@example.com",
  message = "Hello, World!"
}

local body1, content_type1 = multipart.build(data1)
print("Content-Type: " .. content_type1)
print("\nBody preview (first 300 chars):")
print(body1:sub(1, 300))
print("\n")

-- Example 2: File upload
print("Example 2: File upload")
print("-------------------------------------------------")
local data2 = {
  description = "Profile picture upload",
  avatar = {
    [1] = "...binary image data...",
    filename = "profile.jpg",
    ["Content-Type"] = "image/jpeg"
  }
}

local body2, content_type2 = multipart.build(data2)
print("Content-Type: " .. content_type2)
print("\nBody preview (first 300 chars):")
print(body2:sub(1, 300))
print("\n")

-- Example 3: Multiple files (same field name)
print("Example 3: Multiple files (nested multipart/mixed)")
print("-------------------------------------------------")
local data3 = {
  description = "Document upload",
  files = {
    { [1] = "Content of document 1", filename = "doc1.txt", ["Content-Type"] = "text/plain" },
    { [1] = "Content of document 2", filename = "doc2.txt", ["Content-Type"] = "text/plain" },
    { [1] = "Content of document 3", filename = "doc3.txt", ["Content-Type"] = "text/plain" }
  }
}

local body3, content_type3 = multipart.build(data3)
print("Content-Type: " .. content_type3)
print("\nBody preview (first 400 chars):")
print(body3:sub(1, 400))
print("\n")

-- Example 4: Repeated fields (array)
print("Example 4: Repeated fields")
print("-------------------------------------------------")
local data4 = {
  name = "John Doe",
  tags = { "developer", "lua", "open-source" }
}

local body4, content_type4 = multipart.build(data4)
print("Content-Type: " .. content_type4)
print("\nBody preview (first 300 chars):")
print(body4:sub(1, 300))
print("\n")

-- Example 5: Custom boundary
print("Example 5: Custom boundary")
print("-------------------------------------------------")
local data5 = {
  field = "value"
}

local custom_boundary = "MyCustomBoundary123"
local body5, content_type5 = multipart.build(data5, custom_boundary)
print("Content-Type: " .. content_type5)
print("\nBody:")
print(body5)
print("\n")

-- Example 6: Round-trip (build and parse)
print("Example 6: Round-trip test (build and parse)")
print("-------------------------------------------------")
local original_data = {
  name = "Alice",
  age = "30",
  file = {
    [1] = "File content here",
    filename = "data.txt",
    ["Content-Type"] = "text/plain"
  }
}

local body, content_type = multipart.build(original_data)
print("Built multipart data")

local parsed_data = multipart.parse(body, content_type)
print("Parsed it back")

-- Verify round-trip
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

if deep_equal(original_data, parsed_data) then
  print("✓ Round-trip successful! Data preserved.")
else
  print("✗ Round-trip failed! Data mismatch.")
end
print("\n")

-- Example 7: HTTP request simulation
print("Example 7: Simulating HTTP POST request")
print("-------------------------------------------------")
local form_data = {
  email = "user@example.com",
  password = "secret",
  remember_me = "true"
}

local request_body, request_content_type = multipart.build(form_data)

print("POST /login HTTP/1.1")
print("Host: example.com")
print("Content-Type: " .. request_content_type)
print("Content-Length: " .. #request_body)
print("")
print("Body preview:")
print(request_body:sub(1, 200))
print("\n")

print("=================================================")
print("Examples completed successfully!")
print("=================================================")

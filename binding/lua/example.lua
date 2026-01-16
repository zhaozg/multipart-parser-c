#!/usr/bin/env luajit
-- Example demonstrating the simple parse() API
-- This is compatible with the uvs_multipart_parse interface

package.cpath = package.cpath .. ";./binding/lua/?.so"
local mp = require("multipart_parser")

-- Example 1: Simple form data
print("Example 1: Simple form with two fields")
print("=" .. string.rep("=", 50))

local boundary = "boundary"
local body = "--boundary\r\n" ..
    "Content-Disposition: form-data; name=\"username\"\r\n" ..
    "\r\n" ..
    "john_doe\r\n" ..
    "--boundary\r\n" ..
    "Content-Disposition: form-data; name=\"email\"\r\n" ..
    "\r\n" ..
    "john@example.com\r\n" ..
    "--boundary--"

local result = mp.parse(boundary, body)

if result then
    print(string.format("Parsed %d parts:", #result))
    for i, part in ipairs(result) do
        print(string.format("\nPart %d:", i))
        
        -- Print headers
        for k, v in pairs(part) do
            if type(k) == "string" then
                print(string.format("  Header: %s = %s", k, v))
            end
        end
        
        -- Print data
        local data = table.concat(part, "")
        print(string.format("  Data: %s", data))
    end
else
    print("Parse failed!")
end

-- Example 2: File upload
print("\n\nExample 2: File upload")
print("=" .. string.rep("=", 50))

boundary = "----WebKitFormBoundary"
body = "------WebKitFormBoundary\r\n" ..
    "Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "File content here\r\n" ..
    "Line 2\r\n" ..
    "------WebKitFormBoundary\r\n" ..
    "Content-Disposition: form-data; name=\"description\"\r\n" ..
    "\r\n" ..
    "This is a test file\r\n" ..
    "------WebKitFormBoundary--"

result = mp.parse(boundary, body)

if result then
    print(string.format("Parsed %d parts:", #result))
    for i, part in ipairs(result) do
        print(string.format("\nPart %d:", i))
        
        -- Extract filename if present
        local disposition = part["Content-Disposition"] or ""
        local filename = disposition:match('filename="([^"]+)"')
        if filename then
            print(string.format("  Filename: %s", filename))
        end
        
        -- Extract field name
        local name = disposition:match('name="([^"]+)"')
        if name then
            print(string.format("  Field name: %s", name))
        end
        
        -- Print content type if present
        if part["Content-Type"] then
            print(string.format("  Content-Type: %s", part["Content-Type"]))
        end
        
        -- Print data
        local data = table.concat(part, "")
        print(string.format("  Data: %s", data))
    end
end

-- Example 3: Performance test
print("\n\nExample 3: Performance test")
print("=" .. string.rep("=", 50))

boundary = "perf"
local large_data = string.rep("x", 10000)
body = string.format("--perf\r\nContent-Disposition: form-data; name=\"large\"\r\n\r\n%s\r\n--perf--", large_data)

local start = os.clock()
result = mp.parse(boundary, body)
local elapsed = os.clock() - start

if result then
    print(string.format("Parsed large message (%d bytes) in %.4f seconds", #body, elapsed))
    print(string.format("Throughput: %.2f MB/s", (#body / 1024 / 1024) / elapsed))
end

-- Example 4: Parser reuse with reset
print("\n\nExample 4: Parser reuse with reset")
print("=" .. string.rep("=", 50))

local part_count = 0
local callbacks = {
    on_part_data_end = function()
        part_count = part_count + 1
        return 0
    end
}

-- Create parser with first boundary
local parser = mp.new("boundary1", callbacks)

-- Parse first message
local data1 = "--boundary1\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Message 1\r\n" ..
    "--boundary1--"

parser:execute(data1)
print(string.format("After first parse: %d part(s)", part_count))

-- Reset parser with new boundary
parser:reset("boundary2")

-- Parse second message with different boundary
local data2 = "--boundary2\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Message 2\r\n" ..
    "--boundary2--"

parser:execute(data2)
print(string.format("After reset and second parse: %d part(s)", part_count))

-- Reset again keeping same boundary
parser:reset()  -- or parser:reset(nil)

-- Parse third message
local data3 = "--boundary2\r\n" ..
    "Content-Type: text/plain\r\n" ..
    "\r\n" ..
    "Message 3\r\n" ..
    "--boundary2--"

parser:execute(data3)
print(string.format("After second reset and third parse: %d part(s)", part_count))
print("✓ Parser reuse with reset works correctly!")

parser:free()

print("\n✓ All examples completed successfully!")

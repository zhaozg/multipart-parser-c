package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

local mp = require("multipart_parser")

-- Simulate what multipart_compat does
-- First normalize CRLF
local function normalize_crlf(data)
  data = data:gsub("\r\n", "\n")
  data = data:gsub("\n", "\r\n")
  return data
end

local body_raw = [[
--AaB03x
content-disposition: form-data; name="pics"
Content-type: multipart/mixed, boundary=BbC04y

--BbC04y
Content-disposition: attachment; filename="file1.txt"
Content-Type: text/plain

... contents of file1.txt ...
--BbC04y
Content-disposition: attachment; filename="file2.gif"
Content-type: image/gif
Content-Transfer-Encoding: binary

...contents of file2.gif...
--BbC04y--
--AaB03x--
]]

local body = normalize_crlf(body_raw)
print("Body length:", #body)

print("\n=== Parsing outer ===")
local outer_result = mp.parse("AaB03x", body)
print("Result type:", type(outer_result), "#:", #outer_result)

local nested_part = outer_result[1]
local data_chunks = {}
for k, v in pairs(nested_part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
  end
end
local nested_content = table.concat(data_chunks)

print("\nNested content length:", #nested_content)
print("First 150 chars:")
print(string.sub(nested_content, 1, 150))

print("\n=== Parsing nested ===")
local nested_result = mp.parse("BbC04y", nested_content)
print("Result type:", type(nested_result), "#:", #nested_result)
for i = 1, math.min(3, #nested_result) do
  print("  result[" .. i .. "] type:", type(nested_result[i]))
end

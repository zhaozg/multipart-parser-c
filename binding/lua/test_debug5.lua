package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- Parse outer to get nested content
local body = "--AaB03x\r\ncontent-disposition: form-data; name=\"field1\"\r\n\r\nJoe Blow\r\n--AaB03x\r\ncontent-disposition: form-data; name=\"pics\"\r\nContent-type: multipart/mixed, boundary=BbC04y\r\n\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\n... contents of file1.txt ...\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file2.gif\"\r\nContent-type: image/gif\r\nContent-Transfer-Encoding: binary\r\n\r\n...contents of file2.gif...\r\n--BbC04y--\r\n--AaB03x--\r\n"

local result = mp.parse("AaB03x", body)
local nested_part = result[2]
local nested_content = table.concat(nested_part)

print("Nested content (first 200 chars):")
print(string.sub(nested_content, 1, 200))
print("\n\nParsing with BbC04y boundary...")
local nested_result = mp.parse("BbC04y", nested_content)

print("Nested result type:", type(nested_result))
print("#nested_result:", type(nested_result) == "table" and #nested_result or "N/A")

if type(nested_result) == "table" then
  for i = 1, math.min(3, #nested_result) do
    print("\nnested_result[" .. i .. "] type:", type(nested_result[i]))
    if type(nested_result[i]) == "table" then
      for k, v in pairs(nested_result[i]) do
        print("  [" .. tostring(k) .. "] = " .. tostring(v))
      end
    else
      print("  value:", nested_result[i])
    end
  end
end

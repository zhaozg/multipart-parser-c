package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- Parse outer multipart
local outer_body = "--AaB03x\r\ncontent-disposition: form-data; name=\"pics\"\r\nContent-type: multipart/mixed, boundary=BbC04y\r\n\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\n... contents of file1.txt ...\r\n--BbC04y--\r\n--AaB03x--"

print("=== Parsing outer ===")
local outer_result = mp.parse("AaB03x", outer_body)
print("Outer result type:", type(outer_result), "#:", #outer_result)

-- Get the nested content
local nested_part = outer_result[1]
print("\nnested_part type:", type(nested_part))
if type(nested_part) == "table" then
  print("nested_part keys:")
  for k, v in pairs(nested_part) do
    print("  ", k, "=", type(v), string.sub(tostring(v), 1, 50))
  end
end

-- Extract data chunks
local data_chunks = {}
for k, v in pairs(nested_part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
  end
end
local nested_content = table.concat(data_chunks)

print("\nnested_content length:", #nested_content)
print("nested_content first 100 chars:")
print(string.sub(nested_content, 1, 100))

print("\n=== Parsing nested ===")
local nested_result = mp.parse("BbC04y", nested_content)
print("Nested result type:", type(nested_result), "#:", #nested_result)
for i = 1, math.min(3, #nested_result) do
  print("  nested_result[" .. i .. "] type:", type(nested_result[i]))
end

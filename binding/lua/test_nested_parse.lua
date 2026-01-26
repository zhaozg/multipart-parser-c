package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- Parse outer
local body = table.concat({
  "--AaB03x\r\n",
  "content-disposition: form-data; name=\"pics\"\r\n",
  "Content-type: multipart/mixed, boundary=BbC04y\r\n",
  "\r\n",
  "--BbC04y\r\n",
  "Content-disposition: attachment; filename=\"file1.txt\"\r\n",
  "Content-Type: text/plain\r\n",
  "\r\n",
  "AAA\r\n",
  "--BbC04y--\r\n",
  "--AaB03x--",
})

print("Parsing outer...")
local parts, err = mp.parse("AaB03x", body)
print("Outer result:", type(parts), err)
print("#parts:", #parts)

local part = parts[1]
print("\nPart 1 type:", type(part))
for k, v in pairs(part) do
  if type(k) == "string" then
    print("  Header:", k, "=", v)
  else
    print("  Data chunk", k, "length:", #v, "first 50:", string.sub(v, 1, 50))
  end
end

-- Collect data
local data_chunks = {}
for k, v in pairs(part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
  end
end
local nested_content = table.concat(data_chunks)
print("\nNested content length:", #nested_content)
print("First 100 chars:", string.sub(nested_content, 1, 100))

print("\n\nParsing nested...")
local nested_parts, nested_err = mp.parse("BbC04y", nested_content)
print("Nested result:", type(nested_parts), nested_err)
if type(nested_parts) == "table" then
  print("#nested_parts:", #nested_parts)
  for i = 1, #nested_parts do
    print("Nested part", i, "type:", type(nested_parts[i]))
  end
end

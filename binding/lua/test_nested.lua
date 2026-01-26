package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

local body = table.concat({
  "--AaB03x\r\n",
  "content-disposition: form-data; name=\"pics\"\r\n",
  "Content-type: multipart/mixed, boundary=BbC04y\r\n",
  "\r\n",
  "--BbC04y\r\n",
  "Content-disposition: attachment; filename=\"file1.txt\"\r\n",
  "Content-Type: text/plain\r\n",
  "\r\n",
  "... contents of file1.txt ...\r\n",
  "--BbC04y--\r\n",
  "--AaB03x--\r\n",
})

print("Parsing outer...")
local parts = mp.parse("AaB03x", body)
print("#parts:", #parts)

local part = parts[1]
print("\nPart headers:")
for k, v in pairs(part) do
  if type(k) == "string" then
    print("  [" .. k .. "] = " .. v)
  end
end

print("\nPart data chunks:", #part)
local data_chunks = {}
for k, v in pairs(part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
    print("  Chunk " .. k .. " length:", #v)
  end
end

local nested_content = table.concat(data_chunks)
print("\nNested content length:", #nested_content)
print("First 100 chars:")
print(string.sub(nested_content, 1, 100))

print("\n\nParsing nested with boundary BbC04y...")
local nested_parts = mp.parse("BbC04y", nested_content)
print("Type:", type(nested_parts))
if type(nested_parts) == "table" then
  print("#nested_parts:", #nested_parts)
  for i = 1, #nested_parts do
    print("  Part " .. i .. " type:", type(nested_parts[i]))
  end
end

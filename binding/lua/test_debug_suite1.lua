package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

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

print("Parsing outer...")
local parts = mp.parse("AaB03x", body)
print("#parts:", #parts)

print("\nPart 2 (pics):")
local pics_part = parts[2]
for k, v in pairs(pics_part) do
  if type(k) == "string" then
    print("  [" .. k .. "] = " .. v)
  end
end

local data_chunks = {}
for k, v in pairs(pics_part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
  end
end

local nested_content = table.concat(data_chunks)
print("\nNested content length:", #nested_content)
print("First 200 chars:")
print(string.sub(nested_content, 1, 200))

print("\n\nParsing nested...")
local nested_parts = mp.parse("BbC04y", nested_content)
print("Type:", type(nested_parts))
print("#nested_parts:", type(nested_parts) == "table" and #nested_parts or "N/A")

if type(nested_parts) == "table" then
  for i = 1, #nested_parts do
    print("\nNested part " .. i .. ":")
    local part = nested_parts[i]
    for k, v in pairs(part) do
      if type(k) == "string" then
        print("  [" .. k .. "] = " .. v)
      else
        print("  [" .. k .. "] = (data, length " .. #v .. ")")
      end
    end
  end
end

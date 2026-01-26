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
  "--BbC04y\r\n",
  "Content-disposition: attachment; filename=\"file2.gif\"\r\n",
  "Content-type: image/gif\r\n",
  "Content-Transfer-Encoding: binary\r\n",
  "\r\n",
  "...contents of file2.gif...\r\n",
  "--BbC04y--\r\n",
  "--AaB03x--\r\n",
})

local parts = mp.parse("AaB03x", body)
local pics_part = parts[1]

local data_chunks = {}
for k, v in pairs(pics_part) do
  if type(k) == "number" then
    table.insert(data_chunks, v)
  end
end

local nested_content = table.concat(data_chunks)
print("Nested content length:", #nested_content)

-- Show bytes around the first boundary
local pos = nested_content:find("BbC04y")
if pos then
  local start = math.max(1, pos - 10)
  local finish = math.min(#nested_content, pos + 15)
  local excerpt = nested_content:sub(start, finish)
  local display = excerpt:gsub("\r", "\\r"):gsub("\n", "\\n")
  print("Around first BbC04y boundary: [" .. display .. "]")
end

-- Now try parsing it
print("\nParsing nested multipart...")
local nested_parts, err = mp.parse("BbC04y", nested_content)
print("Result type:", type(nested_parts))
if err then
  print("Error:", err)
end
if type(nested_parts) == "table" then
  print("#nested_parts:", #nested_parts)
  for i = 1, math.min(3, #nested_parts) do
    print("  Part " .. i .. " type:", type(nested_parts[i]))
  end
end

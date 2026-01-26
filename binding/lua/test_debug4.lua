package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- Parse the outer multipart first
local body = "--AaB03x\r\ncontent-disposition: form-data; name=\"field1\"\r\n\r\nJoe Blow\r\n--AaB03x\r\ncontent-disposition: form-data; name=\"pics\"\r\nContent-type: multipart/mixed, boundary=BbC04y\r\n\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\n... contents of file1.txt ...\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file2.gif\"\r\nContent-type: image/gif\r\nContent-Transfer-Encoding: binary\r\n\r\n...contents of file2.gif...\r\n--BbC04y--\r\n--AaB03x--\r\n"

local result = mp.parse("AaB03x", body)
local nested_part = result[2]  -- The "pics" part with nested multipart

print("Nested part data chunks:", #nested_part)
local nested_content = table.concat(nested_part)
print("Concatenated nested content length:", #nested_content)
print("\nHex dump of first 100 bytes:")
for i = 1, math.min(100, #nested_content) do
  local byte = string.byte(nested_content, i)
  io.write(string.format("%02X ", byte))
  if i % 16 == 0 then io.write("\n") end
end
print("\n\nActual string (first 200 chars):")
print(string.sub(nested_content, 1, 200))

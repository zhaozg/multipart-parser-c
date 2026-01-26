package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- This is what we get after normalizing to CRLF for the outer multipart
local body = "--AaB03x\r\ncontent-disposition: form-data; name=\"field1\"\r\n\r\nJoe Blow\r\n--AaB03x\r\ncontent-disposition: form-data; name=\"pics\"\r\nContent-type: multipart/mixed, boundary=BbC04y\r\n\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\n... contents of file1.txt ...\r\n--BbC04y\r\nContent-disposition: attachment; filename=\"file2.gif\"\r\nContent-type: image/gif\r\nContent-Transfer-Encoding: binary\r\n\r\n...contents of file2.gif...\r\n--BbC04y--\r\n--AaB03x--\r\n"

print("Parsing outer multipart...")
local result = mp.parse("AaB03x", body)
print("Type:", type(result))
print("Parts:", #result)

for i = 1, #result do
  local part = result[i]
  print("\n=== Part", i, "===")
  print("Part type:", type(part))
  if type(part) == "table" then
    for k, v in pairs(part) do
      if type(k) == "string" then
        print("  Header:", k, "=", v)
      end
    end
    print("  Data chunks:", #part)
    for j = 1, #part do
      print("    Chunk", j, "length:", #part[j], "type:", type(part[j]))
      print("    First 100 chars:", string.sub(part[j], 1, 100))
    end
  else
    print("  Value:", part)
  end
end

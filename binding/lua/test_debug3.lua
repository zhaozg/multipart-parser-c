package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

-- This is what we get from the outer parser for the nested part
local nested_content = "--BbC04y\r\n\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\n\r\nContent-Type: text/plain\r\n\r\n\r\n... contents of file1.txt ...\r\n\r\n--BbC04y\r\n\r\nContent-disposition: attachment; filename=\"file2.gif\"\r\n\r\nContent-type: image/gif\r\n\r\nContent-Transfer-Encoding: binary\r\n\r\n\r\n...contents of file2.gif...\r\n\r\n--BbC04y--"

print("Nested content length:", #nested_content)
print("First 200 chars:")
print(string.sub(nested_content, 1, 200))
print("\n\nParsing nested with boundary BbC04y...")
local result, err = mp.parse("BbC04y", nested_content)
print("Result type:", type(result))
print("Error:", tostring(err))

if type(result) == "table" then
  print("Parts:", #result)
  for i = 1, #result do
    local part = result[i]
    print("\n=== Nested Part", i, "===")
    print("Part type:", type(part))
    if type(part) == "table" then
      for k, v in pairs(part) do
        if type(k) == "string" then
          print("  Header:", k, "=", v)
        end
      end
      print("  Data chunks:", #part)
      for j = 1, #part do
        print("    Chunk", j, "=", part[j])
      end
    else
      print("  Part is string:", part)
    end
  end
end

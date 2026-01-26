package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

local body = "--test\r\nContent-Type: text/plain\r\n\r\nline1\r\nline2\r\nline3\r\n--test--"

local parts = mp.parse("test", body)
local part = parts[1]

print("Data chunks:")
for i = 1, #part do
  print("Chunk " .. i .. ": [" .. part[i] .. "]")
end

print("\nConcatenated:")
print("[" .. table.concat(part) .. "]")

print("\nConcatenated with CRLF:")
print("[" .. table.concat(part, "\r\n") .. "]")

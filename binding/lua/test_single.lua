package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

local mp_compat = require("multipart_compat")
local parse = mp_compat.parse

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

print("Parsing...")
local ret = parse(body, "Content-type: multipart/form-data, boundary=AaB03x")
print("\nResult:")
for k, v in pairs(ret) do
  print("  [" .. tostring(k) .. "] = " .. type(v))
  if type(v) == "table" then
    for k2, v2 in pairs(v) do
      print("    [" .. tostring(k2) .. "] = " .. tostring(v2))
    end
  else
    print("    value: " .. tostring(v))
  end
end

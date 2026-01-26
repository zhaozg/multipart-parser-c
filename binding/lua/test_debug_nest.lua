package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

local mp_compat = require("multipart_compat")
local parse = mp_compat.parse

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
  "--BbC04y\r\n",
  "Content-disposition: attachment; filename=\"file2.gif\"\r\n",
  "Content-type: image/gif\r\n",
  "Content-Transfer-Encoding: binary\r\n",
  "\r\n",
  "BBB\r\n",
  "--BbC04y--\r\n",
  "--AaB03x--",
})

local ret = parse(body, "multipart/form-data; boundary=AaB03x")

print("pics type:", type(ret.pics))
print("#pics:", #ret.pics)
for i = 1, #ret.pics do
  print("\npics[" .. i .. "] type:", type(ret.pics[i]))
  if type(ret.pics[i]) == "table" then
    for k, v in pairs(ret.pics[i]) do
      print("  [" .. tostring(k) .. "] = " .. tostring(v))
    end
  else
    print("  value:", ret.pics[i])
  end
end

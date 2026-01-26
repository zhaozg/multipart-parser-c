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
  "--BbC04y--\r\n",
  "--AaB03x--\r\n",
})

print("Parsing...")
local ret = parse(body, "Content-type: multipart/form-data, boundary=AaB03x")

function dump(t, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(prefix .. "[" .. tostring(k) .. "] = {")
      dump(v, indent + 1)
      print(prefix .. "}")
    else
      print(prefix .. "[" .. tostring(k) .. "] = " .. tostring(v))
    end
  end
end

print("\nResult:")
dump(ret)

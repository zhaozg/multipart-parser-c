package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

local mp_compat = require("multipart_compat")
local parse = mp_compat.parse

local body = [[
--AaB03x
content-disposition: form-data; name="field1"

Joe Blow
--AaB03x
content-disposition: form-data; name="pics"
Content-type: multipart/mixed, boundary=BbC04y

--BbC04y
Content-disposition: attachment; filename="file1.txt"
Content-Type: text/plain

... contents of file1.txt ...
--BbC04y
Content-disposition: attachment; filename="file2.gif"
Content-type: image/gif
Content-Transfer-Encoding: binary

...contents of file2.gif...
--BbC04y--
--AaB03x--
]]

print("Parsing...")
local ret = parse(body, "Content-type: multipart/form-data, boundary=AaB03x")
print("Result type:", type(ret))
if type(ret) == "table" then
  for k, v in pairs(ret) do
    print("Key:", k, "Value type:", type(v))
  end
end

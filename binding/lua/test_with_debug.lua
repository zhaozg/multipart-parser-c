package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

-- Patch multipart_compat to add debug
local code = io.open("multipart_compat.lua"):read("*a")
-- Add debug after filename extraction
code = code:gsub(
  "(local filename = disp and extract_param%(disp, \"filename\"%)",
  "%1\nif nested_boundary then io.stderr:write(string.format(\"  NESTED: disp=%s, filename=%s\\n\", tostring(disp), tostring(filename))) end"
)
-- Add debug at value assignment
code = code:gsub(
  "(if filename ~= nil then)",
  "if nested_boundary then io.stderr:write(string.format(\"  NESTED: Checking filename, filename=%s\\n\", tostring(filename))) end\n          %1"
)
local f = io.open("/tmp/mp_compat_debug.lua", "w")
f:write(code)
f:close()

package.path = "/tmp/?.lua;" .. package.path
local mp_compat = require("mp_compat_debug")

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
  "--BbC04y--\r\n",
  "--AaB03x--",
})

print("Parsing...")
local ret = mp_compat.parse(body, "multipart/form-data; boundary=AaB03x")
print("\nResult pics[1] type:", type(ret.pics[1]))

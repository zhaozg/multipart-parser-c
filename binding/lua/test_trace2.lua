package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

-- Load and instrument more
local code = io.open("multipart_compat.lua"):read("*a")

-- Add trace at file object creation
code = code:gsub(
  "if filename ~= nil then",
  'print(string.format("  TRACE: filename check: filename=%s, disp=%s", tostring(filename), tostring(disp)))\n          if filename ~= nil then\n            print("  TRACE: Creating file object")'
)

-- Add trace at simple value creation
code = code:gsub(
  "value = combined_data",
  'print(string.format("  TRACE: Creating simple value, combined_data=%s", string.sub(combined_data, 1, 30)))\n          value = combined_data'
)

local f = io.open("/tmp/mp_trace2.lua", "w")
f:write(code)
f:close()

package.path = "/tmp/?.lua;" .. package.path
local mp_compat = require("mp_trace2")

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

print("=== Parsing ===")
local ret = mp_compat.parse(body, "multipart/form-data; boundary=AaB03x")
print("\n=== Result ===")
print("pics[1]:", ret.pics[1])

package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

-- Load and instrument the code
local code = io.open("multipart_compat.lua"):read("*a")

-- Add trace at nested multipart detection
code = code:gsub(
  "if nested_boundary then",
  'print("TRACE: nested_boundary detected:", nested_boundary)\n      if nested_boundary then'
)

-- Add trace before parse_multipart call
code = code:gsub(
  "local nested_result = parse_multipart%(nested_boundary, nested_content%)",
  'print("TRACE: Calling parse_multipart, nested_content length:", #nested_content)\n        local nested_result = parse_multipart(nested_boundary, nested_content)\n        print("TRACE: Got nested_result, type:", type(nested_result), "#:", #nested_result)\n        for k,v in pairs(nested_result) do print("  nested_result[" .. tostring(k) .. "] type=" .. type(v)) end'
)

local f = io.open("/tmp/mp_trace.lua", "w")
f:write(code)
f:close()

package.path = "/tmp/?.lua;" .. package.path
local mp_compat = require("mp_trace")

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

print("=== Starting parse ===")
local ret = mp_compat.parse(body, "multipart/form-data; boundary=AaB03x")
print("\n=== Result ===")
print("pics[1] type:", type(ret.pics[1]))

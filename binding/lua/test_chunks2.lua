package.cpath = package.cpath .. ";./?.so"
local mp = require("multipart_parser")

local body = table.concat({
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

local parts = mp.parse("AaB03x", body)
local pics_part = parts[1]

print("Pics part data chunks: " .. #pics_part)
for i = 1, math.min(15, #pics_part) do
  local chunk = pics_part[i]
  local display = chunk:gsub("\r", "\\r"):gsub("\n", "\\n")
  if #display > 60 then display = display:sub(1, 60) .. "..." end
  print(string.format("Chunk %2d (len=%3d): [%s]", i, #chunk, display))
end

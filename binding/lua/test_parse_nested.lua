package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

-- Copy the parse_nested function for testing
local mp = require("multipart_parser")

local function extract_param(header, param_name)
  if not header then return nil end
  local pattern = param_name .. '%s*=%s*"([^"]*)"'
  local value = header:match(pattern)
  if not value then
    pattern = param_name .. '%s*=%s*([^;%s]*)'
    value = header:match(pattern)
  end
  return value
end

local function parse_nested(content, boundary)
  print("parse_nested called with boundary:", boundary, "content length:", #content)
  if not boundary then return nil end
  local nested_result = {}
  local parts, err = mp.parse(boundary, content)
  print("  mp.parse returned:", type(parts), "#parts:", type(parts) == "table" and #parts or "N/A")
  if not parts or type(parts) ~= "table" then return nil end
  for idx, part in ipairs(parts) do
    print("  Processing part", idx, "type:", type(part))
    if type(part) == "table" then
      local item = {}
      local data_chunks = {}
      for k, v in pairs(part) do
        if type(k) == "number" then
          table.insert(data_chunks, v)
        else
          item[k] = v
        end
      end
      local combined_data = table.concat(data_chunks)
      table.insert(item, 1, combined_data)
      local disp = part["Content-Disposition"] or part["content-disposition"]
      if disp then
        local filename = extract_param(disp, "filename")
        if filename then
          item.filename = filename
        end
      end
      print("    Adding item to nested_result, #data_chunks:", #data_chunks, "combined length:", #combined_data)
      table.insert(nested_result, item)
    end
  end
  print("  Returning nested_result with #:", #nested_result)
  return nested_result
end

-- Test it
local content = "--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\n... contents of file1.txt ...\r\n--BbC04y--"
local result = parse_nested(content, "BbC04y")
print("\nFinal result type:", type(result))
if type(result) == "table" then
  print("Final #result:", #result)
  for i = 1, #result do
    print("result[" .. i .. "]:")
    for k, v in pairs(result[i]) do
      print("  [" .. tostring(k) .. "] = " .. tostring(v))
    end
  end
end

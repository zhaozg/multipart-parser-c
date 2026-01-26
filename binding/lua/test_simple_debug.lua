package.cpath = package.cpath .. ";./?.so"
package.path = package.path .. ";./?.lua"

local mp = require("multipart_parser")

-- Inline implementation with debug
local function parse_multipart(boundary, body)
  local result = {}
  local current_headers = {}
  local current_data = {}
  local current_field = nil
  
  local callbacks = {
    on_part_data_begin = function()
      current_headers = {}
      current_data = {}
      return 0
    end,
    
    on_header_field = function(data)
      current_field = data
      return 0
    end,
    
    on_header_value = function(data)
      current_headers[current_field] = data
      return 0
    end,
    
    on_part_data = function(data)
      table.insert(current_data, data)
      return 0
    end,
    
    on_part_data_end = function()
      local disp = current_headers["Content-Disposition"] or current_headers["Content-disposition"] or current_headers["content-disposition"]
      
      -- Extract params
      local function extract_param(header, param_name)
        if not header then return nil end
        local pattern = '[;%s]' .. param_name .. '%s*=%s*"([^"]*)"'
        local value = header:match(pattern)
        if not value then
          pattern = '^' .. param_name .. '%s*=%s*"([^"]*)"'
          value = header:match(pattern)
        end
        return value
      end
      
      local field_name = extract_param(disp, "name")
      local filename = extract_param(disp, "filename")
      local combined_data = table.concat(current_data)
      
      print(string.format("PART: disp=%s, field_name=%s, filename=%s, data=%s", 
        tostring(disp), tostring(field_name), tostring(filename), string.sub(combined_data, 1, 20)))
      
      local value
      if filename then
        value = {combined_data, filename=filename}
        print("  Created file object")
      else
        value = combined_data
        print("  Created string value")
      end
      
      if field_name then
        result[field_name] = value
      else
        local idx = #result + 1
        result[idx] = value
      end
      
      return 0
    end,
  }
  
  local parser = mp.new(boundary, callbacks)
  parser:execute(body)
  parser:free()
  return result
end

-- Test nested
local nested_body = "--BbC04y\r\nContent-disposition: attachment; filename=\"file1.txt\"\r\nContent-Type: text/plain\r\n\r\nAAA\r\n--BbC04y--"
print("=== Parsing nested ===")
local nested_result = parse_multipart("BbC04y", nested_body)
for k, v in pairs(nested_result) do
  print(string.format("nested_result[%s] = %s (type: %s)", tostring(k), tostring(v), type(v)))
  if type(v) == "table" then
    for k2, v2 in pairs(v) do
      print(string.format("  [%s] = %s", tostring(k2), tostring(v2)))
    end
  end
end

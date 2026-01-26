-- Compatibility layer for multipart parser
-- Provides a high-level parse function compatible with existing test expectations
-- Uses callback-based interface for flexible parsing
local mp = require("multipart_parser")

local M = {}

-- Helper to extract value from a header like 'form-data; name="field"'
local function extract_param(header, param_name)
  if not header then return nil end
  -- Use word boundary to avoid matching "filename" when looking for "name"
  local pattern = '[;%s]' .. param_name .. '%s*=%s*"([^"]*)"'
  local value = header:match(pattern)
  if not value then
    pattern = '[;%s]' .. param_name .. '%s*=%s*([^;%s]*)'
    value = header:match(pattern)
  end
  if not value then
    pattern = '^' .. param_name .. '%s*=%s*"([^"]*)"'
    value = header:match(pattern)
  end
  if not value then
    pattern = '^' .. param_name .. '%s*=%s*([^;%s]*)'
    value = header:match(pattern)
  end
  return value
end

-- Helper to extract boundary from Content-Type header
local function extract_boundary(content_type)
  if not content_type then return nil end
  return extract_param(content_type, "boundary")
end

-- Parse multipart data recursively
local function parse_multipart(boundary, body)
  local result = {}
  local current_part = nil
  local current_field = nil
  local current_headers = {}
  local nested_boundary = nil
  local nested_content_chunks = {}
  
  local callbacks = {
    on_part_data_begin = function()
      current_part = {data_chunks = {}}
      current_headers = {}
      current_field = nil
      nested_boundary = nil
      nested_content_chunks = {}
      return 0
    end,
    
    on_header_field = function(data)
      current_field = data
      return 0
    end,
    
    on_header_value = function(data)
      if current_field then
        current_headers[current_field] = data
        current_field = nil
      end
      return 0
    end,
    
    on_headers_complete = function()
      -- Check if this is nested multipart
      local content_type = current_headers["Content-Type"] or current_headers["Content-type"] or current_headers["content-type"]
      if content_type and content_type:match("multipart/") then
        nested_boundary = extract_boundary(content_type)
      end
      return 0
    end,
    
    on_part_data = function(data)
      if nested_boundary then
        -- Collecting nested multipart data
        table.insert(nested_content_chunks, data)
      else
        -- Regular part data
        table.insert(current_part.data_chunks, data)
      end
      return 0
    end,
    
    on_part_data_end = function()
      -- Get disposition header (case-insensitive)
      local disp = current_headers["Content-Disposition"] or current_headers["content-disposition"] or current_headers["Content-disposition"]
      
      -- Extract field name and filename
      local field_name = disp and extract_param(disp, "name")
      local filename = disp and extract_param(disp, "filename")
      
      -- Process the part
      local value
      if nested_boundary then
        -- Parse nested multipart
        local nested_content = table.concat(nested_content_chunks)
        local nested_result = parse_multipart(nested_boundary, nested_content)
        -- For nested multipart/mixed, convert the result to an array
        -- Check if the nested parts have field names or are attachments
        local has_field_names = false
        for k, v in pairs(nested_result) do
          if type(k) == "string" then
            has_field_names = true
            break
          end
        end
        if has_field_names then
          -- Has named fields, return as-is (nested form data)
          value = nested_result
        else
          -- All numeric indices, return as array (multipart/mixed)
          local arr = {}
          for k, v in pairs(nested_result) do
            if type(k) == "number" then
              table.insert(arr, v)
            end
          end
          value = arr
        end
      else
        -- Regular field or file
        local combined_data = table.concat(current_part.data_chunks)
        
        if filename ~= nil then
          -- File upload (has filename parameter)
          value = {combined_data}
          value.filename = filename
          -- Add all headers except Content-Disposition
          -- Preserve original header case (e.g., Content-Type vs Content-type)
          for k, v in pairs(current_headers) do
            local k_lower = k:lower()
            if k_lower ~= "content-disposition" then
              value[k] = v
            end
          end
        else
          -- Simple field (no filename, even if it has Content-Type)
          value = combined_data
        end
      end
      
      -- Add to result
      if field_name then
        if result[field_name] then
          -- Field already exists - convert to or append to array
          if type(result[field_name]) == "table" and result[field_name][1] and not result[field_name].filename then
            -- Already an array
            table.insert(result[field_name], value)
          else
            -- Convert to array
            result[field_name] = {result[field_name], value}
          end
        else
          result[field_name] = value
        end
      else
        -- No field name - use numeric index
        local idx = 1
        while result[idx] do
          idx = idx + 1
        end
        result[idx] = value
      end
      
      return 0
    end,
  }
  
  -- Create parser and execute
  local parser = mp.new(boundary, callbacks)
  if not parser then
    return {}
  end
  
  parser:execute(body)
  parser:free()
  
  return result
end

-- Main parse function compatible with test expectations
function M.parse(body, content_type)
  -- Extract boundary from content type
  local boundary = extract_boundary(content_type)
  if not boundary then
    return {}
  end
  
  -- Parse the multipart body
  return parse_multipart(boundary, body)
end

return M

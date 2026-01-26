-- Compatibility layer for multipart parser
-- Wraps mp.parse to provide test-compatible output format
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

-- Transform mp.parse output to test-compatible format
local function transform_parts(parts)
  local result = {}
  
  for _, part in ipairs(parts) do
    -- Process only if part is a table
    if type(part) == "table" then
      -- Collect headers (case-insensitive)
      local disp = part["Content-Disposition"] or part["content-disposition"]
      local content_type = part["Content-Type"] or part["Content-type"] or part["content-type"]
      
      -- Extract field name and filename
      local field_name = disp and extract_param(disp, "name")
      local filename = disp and extract_param(disp, "filename")
      
      -- Collect data chunks
      local data_chunks = {}
      for k, v in pairs(part) do
        if type(k) == "number" then
          table.insert(data_chunks, v)
        end
      end
      local combined_data = table.concat(data_chunks)
      
      -- Check for nested multipart
      local is_multipart = content_type and content_type:match("multipart/")
      
      local value
      if is_multipart then
        -- Parse nested multipart
        local nested_boundary = extract_boundary(content_type)
        if nested_boundary then
          local nested_parts, err = mp.parse(nested_boundary, combined_data)
          if nested_parts then
            local nested_result = transform_parts(nested_parts)
            -- Check if all nested parts are numeric (multipart/mixed attachments)
            local has_names = false
            for k, v in pairs(nested_result) do
              if type(k) == "string" then
                has_names = true
                break
              end
            end
            if has_names then
              value = nested_result
            else
              -- Convert to array
              local arr = {}
              for i = 1, #nested_result do
                if nested_result[i] then
                  table.insert(arr, nested_result[i])
                end
              end
              value = arr
            end
          else
            -- Nested parse failed, use raw data
            value = combined_data
          end
        else
          value = combined_data
        end
      elseif filename ~= nil then
        -- File upload (has filename parameter)
        value = {combined_data}
        value.filename = filename
        if content_type then
          value["Content-Type"] = content_type
        end
        -- Add other headers (case-insensitive filtering)
        for k, v in pairs(part) do
          if type(k) == "string" then
            local k_lower = k:lower()
            if k_lower ~= "content-disposition" and k_lower ~= "content-type" then
              value[k] = v
            end
          end
        end
      else
        -- Simple field
        value = combined_data
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
    end
  end
  
  return result
end

-- Main parse function compatible with test expectations
function M.parse(body, content_type)
  -- Extract boundary from content type
  local boundary = extract_boundary(content_type)
  if not boundary then
    return {}
  end
  
  -- Parse using mp.parse
  local parts, err = mp.parse(boundary, body)
  if not parts then
    return {}
  end
  
  -- Transform to expected format
  return transform_parts(parts)
end

return M

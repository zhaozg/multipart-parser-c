-- Compatibility layer for multipart parser
-- Provides a high-level parse function compatible with existing test expectations
local mp = require("multipart_parser")

local M = {}

-- Helper to extract value from a header like 'form-data; name="field"'
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

-- Helper to extract boundary from Content-Type header
local function extract_boundary(content_type)
  if not content_type then return nil end
  return extract_param(content_type, "boundary")
end

-- Parse nested multipart/mixed content
local function parse_nested(content, boundary)
  if not boundary then return nil end
  local nested_result = {}
  local parts, err = mp.parse(boundary, content)
  if not parts or type(parts) ~= "table" then return nil end
  for idx, part in ipairs(parts) do
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
      table.insert(nested_result, item)
    end
  end
  return nested_result
end

-- Main parse function compatible with test expectations
function M.parse(body, content_type)
  -- Extract boundary from content type
  local boundary = extract_boundary(content_type)
  if not boundary then
    return {}
  end
  -- Parse using the C parser (body should already have \r\n line endings)
  local parts, err = mp.parse(boundary, body)
  if not parts or type(parts) ~= "table" then
    return {}
  end
  -- Transform to expected format
  local result = {}
  for _, part in ipairs(parts) do
    -- Extract field name from Content-Disposition (case-insensitive)
    local disp = part["Content-Disposition"] or part["content-disposition"]
    local field_name = nil
    if disp then
      field_name = extract_param(disp, "name")
    end
    -- Collect data chunks
    local data_chunks = {}
    for k, v in pairs(part) do
      if type(k) == "number" then
        table.insert(data_chunks, v)
      end
    end
    local combined_data = table.concat(data_chunks)
    -- Check if this is a file (has filename)
    local filename = nil
    if disp then
      filename = extract_param(disp, "filename")
    end
    -- Check for nested multipart (case-insensitive)
    local content_type_header = part["Content-Type"] or part["Content-type"] or part["content-type"]
    local is_multipart = content_type_header and content_type_header:match("multipart/")
    local value
    if is_multipart then
      -- Parse nested multipart
      local nested_boundary = extract_boundary(content_type_header)
      if nested_boundary then
        value = parse_nested(combined_data, nested_boundary)
      else
        value = combined_data
      end
    elseif filename ~= nil or (content_type_header and content_type_header ~= "") then
      -- File or part with Content-Type
      value = { combined_data }
      if filename then
        value.filename = filename
      end
      if content_type_header then
        value["Content-Type"] = content_type_header
      end
      -- Add other headers except Content-Disposition (case-insensitive)
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
        -- Field already exists - convert to array
        if type(result[field_name]) == "table" and result[field_name][1] and not result[field_name].filename then
          -- Already an array of values
          table.insert(result[field_name], value)
        else
          -- Convert to array
          result[field_name] = { result[field_name], value }
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
  return result
end

return M

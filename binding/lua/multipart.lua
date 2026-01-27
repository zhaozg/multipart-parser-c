--- Multipart form-data parser and builder for Lua
-- Provides high-level functions for parsing and building multipart/form-data
-- compatible with RFC 7578 (multipart/form-data) and RFC 2046 (MIME)
--
-- @module multipart
-- @author multipart-parser-c project
-- @license MIT
-- @copyright 2024

local mp = require("multipart_parser")

local M = {}
M._VERSION = "1.0.0"

--- Extract parameter value from a header string
-- Handles both quoted and unquoted parameter values
-- @local
-- @param header (string) Header value to parse
-- @param param_name (string) Parameter name to extract
-- @return (string|nil) Parameter value or nil if not found
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

--- Extract boundary from Content-Type header
-- @local
-- @param content_type (string) Content-Type header value
-- @return (string|nil) Boundary string or nil if not found
local function extract_boundary(content_type)
  if not content_type then return nil end
  return extract_param(content_type, "boundary")
end

--- Parse multipart data recursively
-- Internal function to handle nested multipart messages
-- @local
-- @param boundary (string) Boundary delimiter
-- @param body (string) Multipart message body
-- @return (table) Parsed parts as a table
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

--- Parse multipart/form-data message
-- Parses a multipart message body and returns structured data
--
-- @param body (string) The multipart message body to parse
-- @param content_type (string) Content-Type header value (e.g., "multipart/form-data; boundary=xyz")
--
-- @return (table) Parsed data structure where:
--   - Simple fields are stored as string values
--   - File uploads are stored as tables with [1]=data, filename=name, and headers
--   - Repeated fields become arrays
--   - Parts without names use numeric indices
--   - Nested multipart/mixed are parsed recursively
--
-- @usage
-- local multipart = require("multipart")
-- local body = "--boundary\r\n" ..
--              "Content-Disposition: form-data; name=\"field\"\r\n" ..
--              "\r\n" ..
--              "value\r\n" ..
--              "--boundary--\r\n"
-- local data = multipart.parse(body, "multipart/form-data; boundary=boundary")
-- -- data = {field = "value"}
function M.parse(body, content_type)
  -- Extract boundary from content type
  local boundary = extract_boundary(content_type)
  if not boundary then
    return {}
  end

  -- Parse the multipart body
  return parse_multipart(boundary, body)
end

--- Generate a random boundary string
-- Creates a boundary that is unlikely to appear in content
-- @local
-- @return (string) Random boundary string
local random_seeded = false
local function generate_boundary()
  local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  local boundary = "----MultipartBoundary"
  if not random_seeded then
    math.randomseed(os.time() + os.clock() * 1000000)
    random_seeded = true
  end
  for i = 1, 16 do
    local idx = math.random(1, #chars)
    boundary = boundary .. chars:sub(idx, idx)
  end
  return boundary
end

--- Encode a field name or filename for use in Content-Disposition header
-- Properly quotes and escapes special characters
-- @local
-- @param value (string) Value to encode
-- @return (string) Encoded value
local function encode_disposition_value(value)
  if not value then return '""' end
  -- Escape quotes and backslashes
  local escaped = value:gsub('\\', '\\\\'):gsub('"', '\\"')
  return '"' .. escaped .. '"'
end

--- Build multipart/form-data message from structured data
-- Creates a properly formatted multipart message from Lua data
--
-- @param data (table) Data to encode as multipart, where:
--   - Simple string values become form fields
--   - Tables with [1]=data and filename=name become file uploads
--   - Tables with [1]=data and headers become parts with custom headers
--   - Arrays of values create repeated fields
--   - Nested tables with numeric indices become multipart/mixed
--
-- @param boundary (string|nil) Optional boundary string (auto-generated if nil)
--
-- @return (string, string) Returns two values:
--   1. The multipart message body
--   2. The Content-Type header value (e.g., "multipart/form-data; boundary=xyz")
--
-- @usage
-- local multipart = require("multipart")
-- local data = {
--   field1 = "value1",
--   file = {
--     [1] = "file content",
--     filename = "test.txt",
--     ["Content-Type"] = "text/plain"
--   }
-- }
-- local body, content_type = multipart.build(data)
-- -- Use body and content_type in HTTP request
function M.build(data, boundary)
  if type(data) ~= "table" then
    error("data must be a table", 2)
  end

  -- Generate boundary if not provided
  boundary = boundary or generate_boundary()

  local parts = {}

  -- Helper to build a single part
  local function build_part(name, value)
    local part_lines = {}

    -- Start with boundary
    table.insert(part_lines, "--" .. boundary)

    -- Determine part type and build headers
    if type(value) == "string" then
      -- Simple field
      table.insert(part_lines, "Content-Disposition: form-data; name=" .. encode_disposition_value(name))
      table.insert(part_lines, "")
      table.insert(part_lines, value)
    elseif type(value) == "table" then
      -- Check if it's a file (has [1] and filename)
      local is_file = value[1] ~= nil and value.filename ~= nil
      -- Check if it's nested multipart (numeric keys only, no filename)
      local is_nested = not value.filename and value[1] ~= nil

      if is_file then
        -- File upload
        local disp = "Content-Disposition: form-data; name=" .. encode_disposition_value(name)
        disp = disp .. "; filename=" .. encode_disposition_value(value.filename)
        table.insert(part_lines, disp)

        -- Add other headers (e.g., Content-Type)
        for k, v in pairs(value) do
          if type(k) == "string" and k ~= "filename" then
            table.insert(part_lines, k .. ": " .. v)
          end
        end

        table.insert(part_lines, "")
        table.insert(part_lines, value[1])
      elseif is_nested then
        -- Nested multipart/mixed
        local nested_boundary = generate_boundary()
        local nested_parts = {}

        -- Build each nested part
        for i = 1, #value do
          local nested_value = value[i]
          local nested_part_lines = {}

          table.insert(nested_part_lines, "--" .. nested_boundary)

          if type(nested_value) == "table" and nested_value.filename then
            -- File in nested multipart
            local disp = "Content-Disposition: attachment; filename=" .. encode_disposition_value(nested_value.filename)
            table.insert(nested_part_lines, disp)

            for k, v in pairs(nested_value) do
              if type(k) == "string" and k ~= "filename" then
                table.insert(nested_part_lines, k .. ": " .. v)
              end
            end

            table.insert(nested_part_lines, "")
            table.insert(nested_part_lines, nested_value[1])
          else
            -- Simple data in nested multipart
            table.insert(nested_part_lines, "")
            table.insert(nested_part_lines, tostring(nested_value))
          end

          table.insert(nested_parts, table.concat(nested_part_lines, "\r\n"))
        end

        -- Close nested multipart
        table.insert(nested_parts, "--" .. nested_boundary .. "--")

        -- Build outer part with nested multipart
        local disp = "Content-Disposition: form-data; name=" .. encode_disposition_value(name)
        table.insert(part_lines, disp)
        table.insert(part_lines, "Content-Type: multipart/mixed; boundary=" .. nested_boundary)
        table.insert(part_lines, "")
        table.insert(part_lines, table.concat(nested_parts, "\r\n"))
      else
        -- Table without [1] or filename - treat as simple field with string representation
        table.insert(part_lines, "Content-Disposition: form-data; name=" .. encode_disposition_value(name))
        table.insert(part_lines, "")
        table.insert(part_lines, tostring(value))
      end
    else
      -- Other types - convert to string
      table.insert(part_lines, "Content-Disposition: form-data; name=" .. encode_disposition_value(name))
      table.insert(part_lines, "")
      table.insert(part_lines, tostring(value))
    end

    return table.concat(part_lines, "\r\n")
  end

  -- Helper to check if a table is an array (consecutive numeric keys starting from 1)
  local function is_array(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for k, v in pairs(t) do
      if type(k) == "number" then
        count = count + 1
      end
    end
    -- Check if we have consecutive keys from 1 to count
    for i = 1, count do
      if t[i] == nil then
        return false
      end
    end
    return count > 0
  end

  -- Process all fields
  for name, value in pairs(data) do
    if type(name) == "string" then
      -- Named field
      if type(value) == "table" and not value.filename and is_array(value) and #value > 1 then
        -- Array of values (repeated field) - must have more than 1 element
        for i = 1, #value do
          table.insert(parts, build_part(name, value[i]))
        end
      else
        -- Single value
        table.insert(parts, build_part(name, value))
      end
    end
  end

  -- Close multipart
  table.insert(parts, "--" .. boundary .. "--")

  local body = table.concat(parts, "\r\n")
  local content_type = "multipart/form-data; boundary=" .. boundary

  return body, content_type
end

return M

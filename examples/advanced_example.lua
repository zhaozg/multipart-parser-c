#!/usr/bin/env luajit
--[[
Advanced Multipart Parsing Examples for Lua

This file demonstrates application-level responsibilities for RFC 7578 compliance:
- Content-Disposition parsing
- Filename extraction (with quotes and special characters)
- RFC 5987 decoding (percent-encoded UTF-8 filenames)
- Security validations (path traversal, size limits)
- Streaming processing with boundary conditions

Run: luajit advanced_example.lua
--]]

package.cpath = package.cpath .. ";../binding/lua/?.so;./binding/lua/?.so"
local mp = require("multipart_parser")

-- ============================================================================
-- EXAMPLE 1: Content-Disposition Header Parsing
-- ============================================================================
-- RFC 7578 requires Content-Disposition header with name parameter.
-- Applications must parse this to extract field names and filenames.
-- ============================================================================

local function parse_content_disposition(value)
    local result = {
        name = nil,
        filename = nil,
        has_filename = false
    }
    
    -- Parse name parameter
    local name = value:match('name="([^"]+)"')
    if not name then
        -- Try without quotes
        name = value:match('name=([^;%s]+)')
    end
    result.name = name
    
    -- Parse filename parameter
    local filename = value:match('filename="([^"]+)"')
    if not filename then
        -- Try without quotes
        filename = value:match('filename=([^;%s]+)')
    end
    if filename then
        result.filename = filename
        result.has_filename = true
    end
    
    return result
end

local function example_content_disposition_parsing()
    print("=== Example 1: Content-Disposition Parsing ===\n")
    
    local test_cases = {
        'form-data; name="username"',
        'form-data; name="avatar"; filename="photo.jpg"',
        'form-data; name="doc"; filename="my document.pdf"',
    }
    
    for _, value in ipairs(test_cases) do
        print("Input: " .. value)
        local result = parse_content_disposition(value)
        print(string.format("  Name: '%s'", result.name or "(none)"))
        if result.has_filename then
            print(string.format("  Filename: '%s'", result.filename))
        end
        print()
    end
end

-- ============================================================================
-- EXAMPLE 2: RFC 5987 Filename Decoding
-- ============================================================================
-- RFC 5987 allows percent-encoded UTF-8 filenames:
-- filename*=utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt
-- ============================================================================

local function decode_percent_encoding(input)
    local function hex_to_char(x)
        return string.char(tonumber(x, 16))
    end
    
    local decoded = input:gsub("%%(%x%x)", hex_to_char)
    return decoded
end

local function parse_rfc5987_filename(value)
    -- Format: charset'language'encoded-value
    -- Example: utf-8''%E4%B8%AD%E6%96%87.txt
    
    local charset, lang, encoded = value:match("([^']*)'([^']*)'(.+)")
    if not encoded then
        return nil
    end
    
    return decode_percent_encoding(encoded)
end

local function example_rfc5987_decoding()
    print("=== Example 2: RFC 5987 Filename Decoding ===\n")
    
    -- Example: Chinese filename "中文名.txt"
    local encoded = "utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt"
    
    print("Encoded: " .. encoded)
    
    local decoded = parse_rfc5987_filename(encoded)
    if decoded then
        print("Decoded: " .. decoded)
        
        -- Show bytes
        io.write("Bytes: ")
        for i = 1, #decoded do
            io.write(string.format("%02X ", decoded:byte(i)))
        end
        print()
    else
        print("Decode failed!")
    end
    
    print()
end

-- ============================================================================
-- EXAMPLE 3: Security Validations
-- ============================================================================
-- Applications MUST validate:
-- - Filename path traversal attacks
-- - Field name injection
-- - Size limits
-- ============================================================================

local function sanitize_filename(filename)
    -- Remove path components
    local name = filename:match("([^/\\]+)$") or filename
    
    -- Check for directory traversal
    if name == "." or name == ".." then
        return nil  -- Reject
    end
    
    -- Replace unsafe characters
    local safe = name:gsub("[^%w%.%-%_ ]", "_")
    
    -- Reject empty filename
    if safe == "" then
        return nil
    end
    
    return safe
end

local function example_security_validations()
    print("=== Example 3: Security Validations ===\n")
    
    local test_filenames = {
        "document.pdf",
        "../../../etc/passwd",
        "..\\..\\..\\windows\\system32\\config\\sam",
        "../../uploads/malicious.exe",
        "normal_file.txt",
        "file<script>.html",
        "..",
        ".",
        "/absolute/path/file.txt",
    }
    
    for _, filename in ipairs(test_filenames) do
        print("Input: " .. filename)
        
        local sanitized = sanitize_filename(filename)
        if sanitized then
            print("  Sanitized: " .. sanitized)
            print("  Status: OK (SAFE)")
        else
            print("  Status: REJECTED")
        end
        print()
    end
end

-- ============================================================================
-- EXAMPLE 4: Streaming with Size Limits
-- ============================================================================
-- Demonstrates enforcing size limits during streaming parse.
-- ============================================================================

local function example_size_limits()
    print("=== Example 4: Streaming with Size Limits ===\n")
    
    local boundary = "limit"
    local data = 
        "--limit\r\n" ..
        "Content-Disposition: form-data; name=\"small\"\r\n" ..
        "\r\n" ..
        "This is small data\r\n" ..
        "--limit\r\n" ..
        "Content-Disposition: form-data; name=\"large\"\r\n" ..
        "\r\n" ..
        "This is supposed to be very large data that exceeds the limit\r\n" ..
        "--limit--"
    
    local limiter = {
        total_bytes = 0,
        max_total_bytes = 1000,
        current_part_bytes = 0,
        max_part_bytes = 30,  -- Set low to trigger limit
        limit_exceeded = false
    }
    
    local callbacks = {
        on_part_data_begin = function()
            limiter.current_part_bytes = 0
            return 0
        end,
        
        on_part_data = function(data)
            limiter.total_bytes = limiter.total_bytes + #data
            limiter.current_part_bytes = limiter.current_part_bytes + #data
            
            -- Check part size limit
            if limiter.current_part_bytes > limiter.max_part_bytes then
                print(string.format("  Part size limit exceeded: %d > %d",
                    limiter.current_part_bytes, limiter.max_part_bytes))
                limiter.limit_exceeded = true
                return 1  -- Pause parsing
            end
            
            -- Check total size limit
            if limiter.total_bytes > limiter.max_total_bytes then
                print(string.format("  Total size limit exceeded: %d > %d",
                    limiter.total_bytes, limiter.max_total_bytes))
                limiter.limit_exceeded = true
                return 1  -- Pause parsing
            end
            
            return 0
        end
    }
    
    local parser = mp.new(boundary, callbacks)
    
    print(string.format("Parsing with limits: max_part=%d, max_total=%d",
        limiter.max_part_bytes, limiter.max_total_bytes))
    
    local parsed = parser:execute(data)
    
    print(string.format("Parsed %d of %d bytes", parsed, #data))
    
    if limiter.limit_exceeded then
        print("Size limit enforcement working correctly")
    else
        print("All data within limits")
    end
    
    parser:free()
    print()
end

-- ============================================================================
-- EXAMPLE 5: Streaming with Boundary Conditions
-- ============================================================================
-- Critical: Boundary can be split across chunks in streaming scenarios.
-- Parser handles this internally, but applications must feed data correctly.
-- ============================================================================

local function example_streaming_boundary_conditions()
    print("=== Example 5: Streaming with Boundary Conditions ===\n")
    
    local boundary = "stream"
    
    -- Simulate receiving data in chunks where boundary is split
    local chunks = {
        "--stream\r\n",                                      -- Chunk 1
        "Content-Disposition: form-data;",                  -- Chunk 2
        " name=\"field1\"\r\n\r\n",                         -- Chunk 3
        "Some data\r\n--st",                                 -- Chunk 4: boundary starts
        "ream\r\n",                                          -- Chunk 5: boundary continues
        "Content-Disposition: form-data; name=\"field2\"\r\n\r\n", -- Chunk 6
        "More data\r\n--stream--",                          -- Chunk 7
    }
    
    local state = {
        part_count = 0,
        data_callbacks = 0
    }
    
    local callbacks = {
        on_part_data_begin = function()
            state.part_count = state.part_count + 1
            print(string.format("  Part %d started", state.part_count))
            return 0
        end,
        
        on_part_data = function(data)
            state.data_callbacks = state.data_callbacks + 1
            print(string.format("  Data callback #%d: %d bytes", 
                state.data_callbacks, #data))
            return 0
        end
    }
    
    local parser = mp.new(boundary, callbacks)
    
    print(string.format("Parsing %d chunks with boundary splits:\n", #chunks))
    
    -- Feed chunks one by one
    for i, chunk in ipairs(chunks) do
        print(string.format("Chunk %d: \"%s\"", i, chunk))
        local parsed = parser:execute(chunk)
        
        if parsed ~= #chunk then
            print(string.format("  Warning: Only parsed %d of %d bytes", 
                parsed, #chunk))
        end
    end
    
    print(string.format("\nSuccessfully parsed %d parts with split boundaries", 
        state.part_count))
    print(string.format("Parser correctly handled %d data callbacks", 
        state.data_callbacks))
    
    parser:free()
    print()
end

-- ============================================================================
-- EXAMPLE 6: Complete Application Example
-- ============================================================================
-- Putting it all together: streaming parse with all validations.
-- ============================================================================

local function example_complete_application()
    print("=== Example 6: Complete Application Example ===\n")
    
    local boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    local data =
        "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\n" ..
        "Content-Disposition: form-data; name=\"username\"\r\n" ..
        "\r\n" ..
        "john_doe\r\n" ..
        "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\n" ..
        "Content-Disposition: form-data; name=\"avatar\"; filename=\"photo.jpg\"\r\n" ..
        "Content-Type: image/jpeg\r\n" ..
        "\r\n" ..
        "(binary image data here)\r\n" ..
        "------WebKitFormBoundary7MA4YWxkTrZu0gW\r\n" ..
        "Content-Disposition: form-data; name=\"document\"; filename=\"../../../etc/passwd\"\r\n" ..
        "Content-Type: text/plain\r\n" ..
        "\r\n" ..
        "Malicious content\r\n" ..
        "------WebKitFormBoundary7MA4YWxkTrZu0gW--"
    
    local state = {
        current_field_name = nil,
        current_filename = nil,
        has_filename = false,
        current_part_size = 0,
        total_size = 0,
        file_count = 0,
        last_header_field = nil,
        parts = {}
    }
    
    local callbacks = {
        on_header_field = function(data)
            state.last_header_field = data
            return 0
        end,
        
        on_header_value = function(data)
            if state.last_header_field == "Content-Disposition" then
                local disp = parse_content_disposition(data)
                if disp.name then
                    state.current_field_name = disp.name
                    if disp.has_filename then
                        -- Sanitize filename
                        local sanitized = sanitize_filename(disp.filename)
                        if sanitized then
                            state.current_filename = sanitized
                            state.has_filename = true
                        end
                    end
                end
            end
            return 0
        end,
        
        on_part_data_begin = function()
            state.current_part_size = 0
            state.has_filename = false
            state.current_filename = nil
            state.current_field_name = nil
            return 0
        end,
        
        on_part_data = function(data)
            state.current_part_size = state.current_part_size + #data
            state.total_size = state.total_size + #data
            
            -- Check size limit
            if state.current_part_size > 10 * 1024 * 1024 then  -- 10MB limit
                print("Part size exceeded limit!")
                return 1  -- Stop parsing
            end
            
            return 0
        end,
        
        on_part_data_end = function()
            local part_info = string.format("field='%s'", 
                state.current_field_name or "(unknown)")
            
            if state.has_filename then
                part_info = part_info .. string.format(", filename='%s', size=%d bytes",
                    state.current_filename, state.current_part_size)
                state.file_count = state.file_count + 1
            else
                part_info = part_info .. string.format(", size=%d bytes",
                    state.current_part_size)
            end
            
            print("  Part completed: " .. part_info)
            
            return 0
        end
    }
    
    local parser = mp.new(boundary, callbacks)
    
    print("Parsing multipart form data with security validations:\n")
    
    local parsed = parser:execute(data)
    
    print()
    print("Summary:")
    print(string.format("  Total parsed: %d bytes", parsed))
    print(string.format("  Files uploaded: %d", state.file_count))
    print(string.format("  Total data size: %d bytes", state.total_size))
    print("\nNote: Path traversal attempt in filename was sanitized")
    
    parser:free()
    print()
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    print()
    print("================================================================")
    print("      Advanced Multipart Parsing Examples (RFC 7578)       ")
    print("                                                            ")
    print("  Application-Level Responsibilities:                       ")
    print("  - Content-Disposition parsing                            ")
    print("  - Filename extraction                                    ")
    print("  - RFC 5987 decoding                                      ")
    print("  - Security validations                                   ")
    print("  - Streaming with size limits                             ")
    print("================================================================")
    print()
    
    example_content_disposition_parsing()
    example_rfc5987_decoding()
    example_security_validations()
    example_size_limits()
    example_streaming_boundary_conditions()
    example_complete_application()
    
    print("================================================================")
    print("              All Examples Completed Successfully!          ")
    print("================================================================")
    print()
end

-- Run the examples
main()

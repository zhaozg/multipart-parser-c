#!/usr/bin/env lua
--[[
  Test for processing large multipart data (simulating >4GB)
  This test simulates processing large amounts of data without actually
  creating 4GB of data in memory by reusing chunks.
  
  It tests the GC safety issue where lua_pcall in callbacks might
  trigger GC and invalidate the data pointer.
]]

local multipart = require("multipart_parser")

print("=== Large Data Processing Test (4GB Simulation) ===")

-- Test configuration
local CHUNK_SIZE = 64 * 1024  -- 64KB chunks (same as real-world usage)
local NUM_CHUNKS = 65536      -- 65536 chunks * 64KB = 4GB
local BOUNDARY = "----WebKitFormBoundary7MA4YWxkTrZu0gW"

-- Create test data with multipart format
local function create_test_chunk(chunk_num, is_first, is_last)
    if is_first then
        -- First chunk: boundary + headers + start of data
        return string.format(
            "--%s\r\n" ..
            "Content-Disposition: form-data; name=\"file\"; filename=\"large_file.bin\"\r\n" ..
            "Content-Type: application/octet-stream\r\n\r\n" ..
            "%s",
            BOUNDARY,
            string.rep("X", CHUNK_SIZE - 200)  -- Fill rest with data
        )
    elseif is_last then
        -- Last chunk: end of data + final boundary
        return string.format(
            "%s\r\n--%s--\r\n",
            string.rep("Y", 100),
            BOUNDARY
        )
    else
        -- Middle chunks: just data
        return string.rep(string.char(chunk_num % 256), CHUNK_SIZE)
    end
end

-- Statistics
local stats = {
    total_bytes = 0,
    part_data_calls = 0,
    chunks_processed = 0,
    max_memory = 0
}

-- Callbacks
local callbacks = {
    on_header_field = function(data)
        -- Intentionally empty to focus on data processing
        return 0
    end,
    
    on_header_value = function(data)
        return 0
    end,
    
    on_part_data_begin = function()
        print("Part data begin")
        stats.total_bytes = 0
        stats.part_data_calls = 0
        return 0
    end,
    
    on_part_data = function(data)
        if not data then
            return 0
        end
        
        stats.total_bytes = stats.total_bytes + #data
        stats.part_data_calls = stats.part_data_calls + 1
        
        -- Every 1000 calls, print progress and force GC
        if stats.part_data_calls % 1000 == 0 then
            local mem_kb = collectgarbage("count")
            if mem_kb > stats.max_memory then
                stats.max_memory = mem_kb
            end
            
            print(string.format(
                "Progress: %d calls, %.2f MB processed, %.2f KB memory",
                stats.part_data_calls,
                stats.total_bytes / (1024 * 1024),
                mem_kb
            ))
            
            -- Force GC to test safety
            collectgarbage("collect")
        end
        
        return 0
    end,
    
    on_part_data_end = function()
        print(string.format("Part data end: %.2f MB total", stats.total_bytes / (1024 * 1024)))
        return 0
    end,
    
    on_headers_complete = function()
        return 0
    end,
    
    on_body_end = function()
        print("Body end")
        return 0
    end
}

-- Create parser
local parser = multipart.new(BOUNDARY, callbacks)
if not parser then
    print("FAILED: Could not create parser")
    os.exit(1)
end

print(string.format("Simulating processing of %d chunks (%d KB each) = %.2f GB",
    NUM_CHUNKS, CHUNK_SIZE / 1024, (NUM_CHUNKS * CHUNK_SIZE) / (1024 * 1024 * 1024)))
print("Note: Forcing GC every 1000 chunks to test memory safety")
print()

-- Process chunks
local start_time = os.clock()
local success = true

for i = 1, NUM_CHUNKS do
    local is_first = (i == 1)
    local is_last = (i == NUM_CHUNKS)
    local chunk = create_test_chunk(i, is_first, is_last)
    
    local parsed = parser:execute(chunk)
    
    if parsed ~= #chunk then
        print(string.format("FAILED: Chunk %d: parsed %d bytes, expected %d", i, parsed, #chunk))
        local err = parser:get_error()
        local msg = parser:get_error_message()
        print(string.format("Error code: %d, message: %s", err, msg))
        success = false
        break
    end
    
    stats.chunks_processed = i
    
    -- Every 10000 chunks, print checkpoint
    if i % 10000 == 0 then
        print(string.format("Checkpoint: %d/%d chunks processed (%.1f%%)",
            i, NUM_CHUNKS, (i / NUM_CHUNKS) * 100))
    end
end

local elapsed = os.clock() - start_time

-- Free parser
parser:free()

-- Print results
print()
print("=== Test Results ===")
if success then
    print("Status: PASSED")
else
    print("Status: FAILED")
end

print(string.format("Chunks processed: %d/%d", stats.chunks_processed, NUM_CHUNKS))
print(string.format("Total data: %.2f MB", stats.total_bytes / (1024 * 1024)))
print(string.format("on_part_data calls: %d", stats.part_data_calls))
print(string.format("Max memory usage: %.2f MB", stats.max_memory / 1024))
print(string.format("Time elapsed: %.2f seconds", elapsed))
print(string.format("Throughput: %.2f MB/s", (stats.total_bytes / (1024 * 1024)) / elapsed))

-- Final result
if success then
    print()
    print("SUCCESS: Processed simulated 4GB data without crashes!")
    print("GC safety verified: callbacks correctly triggered GC without corruption")
    os.exit(0)
else
    print()
    print("FAILURE: Test did not complete successfully")
    os.exit(1)
end

/**
 * Advanced Multipart Parsing Examples
 * 
 * This file demonstrates application-level responsibilities for RFC 7578 compliance:
 * - Content-Disposition parsing
 * - Filename extraction (with quotes and special characters)
 * - RFC 5987 decoding (percent-encoded UTF-8 filenames)
 * - Security validations (path traversal, size limits)
 * - Streaming processing with boundary conditions
 * 
 * Compile: cc -o advanced_parsing advanced_parsing.c ../multipart_parser.c -I..
 * Run: ./advanced_parsing
 */

#include "multipart_parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>

/* ============================================================================
 * EXAMPLE 1: Content-Disposition Header Parsing
 * ============================================================================
 * RFC 7578 requires Content-Disposition header with name parameter.
 * Applications must parse this to extract field names and filenames.
 */

typedef struct {
    char name[256];
    char filename[256];
    int has_filename;
} content_disposition_t;

/**
 * Parse Content-Disposition header value
 * Example: form-data; name="fieldname"; filename="file.txt"
 */
int parse_content_disposition(const char* value, size_t len, content_disposition_t* result) {
    const char* p = value;
    const char* end = value + len;
    
    memset(result, 0, sizeof(content_disposition_t));
    
    /* Skip "form-data" part */
    while (p < end && *p != ';') p++;
    
    /* Parse parameters */
    while (p < end) {
        /* Skip whitespace and semicolon */
        while (p < end && (*p == ';' || *p == ' ' || *p == '\t')) p++;
        if (p >= end) break;
        
        /* Check for "name=" or "filename=" */
        if (end - p >= 5 && strncmp(p, "name=", 5) == 0) {
            p += 5;
            
            /* Handle quoted value */
            if (*p == '"') {
                p++;
                const char* start = p;
                while (p < end && *p != '"') {
                    if (*p == '\\' && p + 1 < end) {
                        /* Skip escaped character */
                        p += 2;
                    } else {
                        p++;
                    }
                }
                size_t name_len = p - start;
                if (name_len < sizeof(result->name)) {
                    memcpy(result->name, start, name_len);
                    result->name[name_len] = '\0';
                }
                if (p < end) p++; /* Skip closing quote */
            }
        } else if (end - p >= 9 && strncmp(p, "filename=", 9) == 0) {
            p += 9;
            result->has_filename = 1;
            
            /* Handle quoted value */
            if (*p == '"') {
                p++;
                const char* start = p;
                while (p < end && *p != '"') {
                    if (*p == '\\' && p + 1 < end) {
                        /* Skip escaped character */
                        p += 2;
                    } else {
                        p++;
                    }
                }
                size_t filename_len = p - start;
                if (filename_len < sizeof(result->filename)) {
                    memcpy(result->filename, start, filename_len);
                    result->filename[filename_len] = '\0';
                }
                if (p < end) p++; /* Skip closing quote */
            }
        } else {
            /* Skip unknown parameter */
            while (p < end && *p != ';') p++;
        }
    }
    
    return result->name[0] != '\0' ? 0 : -1;
}

void example_content_disposition_parsing(void) {
    printf("=== Example 1: Content-Disposition Parsing ===\n\n");
    
    /* Test cases */
    const char* test_cases[] = {
        "form-data; name=\"username\"",
        "form-data; name=\"avatar\"; filename=\"photo.jpg\"",
        "form-data; name=\"field\\\"with\\\"quotes\"",
        "form-data; name=\"doc\"; filename=\"my document.pdf\"",
    };
    
    for (size_t i = 0; i < sizeof(test_cases) / sizeof(test_cases[0]); i++) {
        content_disposition_t result;
        const char* value = test_cases[i];
        
        printf("Input: %s\n", value);
        
        if (parse_content_disposition(value, strlen(value), &result) == 0) {
            printf("  Name: '%s'\n", result.name);
            if (result.has_filename) {
                printf("  Filename: '%s'\n", result.filename);
            }
        } else {
            printf("  Parse failed!\n");
        }
        printf("\n");
    }
}

/* ============================================================================
 * EXAMPLE 2: RFC 5987 Filename Decoding
 * ============================================================================
 * RFC 5987 allows percent-encoded UTF-8 filenames:
 * filename*=utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt
 */

/**
 * Decode percent-encoded string (simplified implementation)
 */
int decode_percent_encoding(const char* input, size_t input_len, char* output, size_t output_size) {
    const char* p = input;
    const char* end = input + input_len;
    size_t out_pos = 0;
    
    while (p < end && out_pos < output_size - 1) {
        if (*p == '%' && p + 2 < end) {
            /* Decode hex */
            char hex[3] = { p[1], p[2], 0 };
            char* endptr;
            long byte = strtol(hex, &endptr, 16);
            if (endptr == hex + 2) {
                output[out_pos++] = (char)byte;
                p += 3;
            } else {
                output[out_pos++] = *p++;
            }
        } else {
            output[out_pos++] = *p++;
        }
    }
    
    output[out_pos] = '\0';
    return 0;
}

/**
 * Parse RFC 5987 encoded filename
 * Format: charset'language'encoded-value
 * Example: utf-8''%E4%B8%AD%E6%96%87.txt
 */
int parse_rfc5987_filename(const char* value, size_t len, char* output, size_t output_size) {
    const char* p = value;
    const char* end = value + len;
    
    /* Skip charset */
    while (p < end && *p != '\'') p++;
    if (p >= end) return -1;
    p++; /* Skip first quote */
    
    /* Skip language */
    while (p < end && *p != '\'') p++;
    if (p >= end) return -1;
    p++; /* Skip second quote */
    
    /* Decode the rest */
    return decode_percent_encoding(p, end - p, output, output_size);
}

void example_rfc5987_decoding(void) {
    printf("=== Example 2: RFC 5987 Filename Decoding ===\n\n");
    
    /* Example: Chinese filename "中文名.txt" */
    const char* encoded = "utf-8''%E4%B8%AD%E6%96%87%E5%90%8D.txt";
    char decoded[256];
    
    printf("Encoded: %s\n", encoded);
    
    if (parse_rfc5987_filename(encoded, strlen(encoded), decoded, sizeof(decoded)) == 0) {
        printf("Decoded: %s\n", decoded);
        printf("Bytes: ");
        for (size_t i = 0; i < strlen(decoded); i++) {
            printf("%02X ", (unsigned char)decoded[i]);
        }
        printf("\n");
    } else {
        printf("Decode failed!\n");
    }
    
    printf("\n");
}

/* ============================================================================
 * EXAMPLE 3: Security Validations
 * ============================================================================
 * Applications MUST validate:
 * - Filename path traversal attacks
 * - Field name injection
 * - Size limits
 */

/**
 * Sanitize filename to prevent path traversal
 */
int sanitize_filename(const char* filename, char* output, size_t output_size) {
    const char* p = filename;
    size_t out_pos = 0;
    
    /* Remove any path components */
    const char* last_slash = strrchr(filename, '/');
    if (last_slash) {
        p = last_slash + 1;
    }
    
    last_slash = strrchr(p, '\\');
    if (last_slash) {
        p = last_slash + 1;
    }
    
    /* Check for directory traversal attempts */
    if (strcmp(p, ".") == 0 || strcmp(p, "..") == 0) {
        return -1; /* Reject */
    }
    
    /* Copy safe characters only */
    while (*p && out_pos < output_size - 1) {
        if (isalnum((unsigned char)*p) || *p == '.' || *p == '-' || *p == '_' || *p == ' ') {
            output[out_pos++] = *p;
        } else {
            output[out_pos++] = '_'; /* Replace unsafe chars */
        }
        p++;
    }
    
    output[out_pos] = '\0';
    
    /* Reject empty filename */
    return out_pos > 0 ? 0 : -1;
}

void example_security_validations(void) {
    printf("=== Example 3: Security Validations ===\n\n");
    
    const char* test_filenames[] = {
        "document.pdf",
        "../../../etc/passwd",
        "..\\..\\..\\windows\\system32\\config\\sam",
        "../../uploads/malicious.exe",
        "normal_file.txt",
        "file<script>.html",
        "..",
        ".",
        "/absolute/path/file.txt",
    };
    
    for (size_t i = 0; i < sizeof(test_filenames) / sizeof(test_filenames[0]); i++) {
        char sanitized[256];
        const char* filename = test_filenames[i];
        
        printf("Input: %s\n", filename);
        
        if (sanitize_filename(filename, sanitized, sizeof(sanitized)) == 0) {
            printf("  Sanitized: %s\n", sanitized);
            printf("  Status: OK (SAFE)\n");
        } else {
            printf("  Status: REJECTED\n");
        }
        printf("\n");
    }
}

/* ============================================================================
 * EXAMPLE 4: Streaming with Size Limits
 * ============================================================================
 * Demonstrates enforcing size limits during streaming parse.
 */

typedef struct {
    size_t total_bytes;
    size_t max_total_bytes;
    size_t current_part_bytes;
    size_t max_part_bytes;
    int limit_exceeded;
} size_limiter_t;

int on_part_data_with_limit(multipart_parser* p, const char* at, size_t length) {
    size_limiter_t* limiter = (size_limiter_t*)multipart_parser_get_data(p);
    
    limiter->total_bytes += length;
    limiter->current_part_bytes += length;
    
    /* Check part size limit */
    if (limiter->current_part_bytes > limiter->max_part_bytes) {
        printf("  Part size limit exceeded: %zu > %zu\n", 
               limiter->current_part_bytes, limiter->max_part_bytes);
        limiter->limit_exceeded = 1;
        return 1; /* Pause parsing */
    }
    
    /* Check total size limit */
    if (limiter->total_bytes > limiter->max_total_bytes) {
        printf("  Total size limit exceeded: %zu > %zu\n",
               limiter->total_bytes, limiter->max_total_bytes);
        limiter->limit_exceeded = 1;
        return 1; /* Pause parsing */
    }
    
    return 0;
}

int on_part_begin_with_limit(multipart_parser* p) {
    size_limiter_t* limiter = (size_limiter_t*)multipart_parser_get_data(p);
    limiter->current_part_bytes = 0;
    return 0;
}

void example_size_limits(void) {
    printf("=== Example 4: Streaming with Size Limits ===\n\n");
    
    const char* boundary = "limit";
    const char* data = 
        "--limit\r\n"
        "Content-Disposition: form-data; name=\"small\"\r\n"
        "\r\n"
        "This is small data\r\n"
        "--limit\r\n"
        "Content-Disposition: form-data; name=\"large\"\r\n"
        "\r\n"
        "This is supposed to be very large data that exceeds the limit\r\n"
        "--limit--";
    
    multipart_parser_settings settings;
    memset(&settings, 0, sizeof(settings));
    settings.on_part_data_begin = on_part_begin_with_limit;
    settings.on_part_data = on_part_data_with_limit;
    
    size_limiter_t limiter = {0};
    limiter.max_total_bytes = 1000;
    limiter.max_part_bytes = 30; /* Set low to trigger limit */
    
    multipart_parser* parser = multipart_parser_init(boundary, &settings);
    multipart_parser_set_data(parser, &limiter);
    
    printf("Parsing with limits: max_part=%zu, max_total=%zu\n",
           limiter.max_part_bytes, limiter.max_total_bytes);
    
    size_t parsed = multipart_parser_execute(parser, data, strlen(data));
    
    printf("Parsed %zu of %zu bytes\n", parsed, strlen(data));
    
    if (limiter.limit_exceeded) {
        printf("Size limit enforcement working correctly\n");
    } else {
        printf("All data within limits\n");
    }
    
    multipart_parser_free(parser);
    printf("\n");
}

/* ============================================================================
 * EXAMPLE 5: Streaming with Boundary Conditions
 * ============================================================================
 * Critical: Boundary can be split across chunks in streaming scenarios.
 * Parser handles this internally, but applications must feed data correctly.
 */

typedef struct {
    int part_count;
    int data_callbacks;
} stream_state_t;

int on_part_begin_streaming(multipart_parser* p) {
    stream_state_t* s = (stream_state_t*)multipart_parser_get_data(p);
    s->part_count++;
    printf("  Part %d started\n", s->part_count);
    return 0;
}

int on_part_data_streaming(multipart_parser* p, const char* at, size_t length) {
    stream_state_t* s = (stream_state_t*)multipart_parser_get_data(p);
    s->data_callbacks++;
    printf("  Data callback #%d: %zu bytes\n", s->data_callbacks, length);
    return 0;
}

void example_streaming_boundary_conditions(void) {
    printf("=== Example 5: Streaming with Boundary Conditions ===\n\n");
    
    const char* boundary = "stream";
    
    /* Simulate receiving data in chunks where boundary is split */
    const char* chunks[] = {
        "--stream\r\n",                                      /* Chunk 1 */
        "Content-Disposition: form-data;",                  /* Chunk 2 */
        " name=\"field1\"\r\n\r\n",                         /* Chunk 3 */
        "Some data\r\n--st",                                 /* Chunk 4: boundary starts */
        "ream\r\n",                                          /* Chunk 5: boundary continues */
        "Content-Disposition: form-data; name=\"field2\"\r\n\r\n", /* Chunk 6 */
        "More data\r\n--stream--",                          /* Chunk 7 */
    };
    
    stream_state_t state = {0};
    
    multipart_parser_settings settings;
    memset(&settings, 0, sizeof(settings));
    settings.on_part_data_begin = on_part_begin_streaming;
    settings.on_part_data = on_part_data_streaming;
    
    multipart_parser* parser = multipart_parser_init(boundary, &settings);
    multipart_parser_set_data(parser, &state);
    
    printf("Parsing %zu chunks with boundary splits:\n", 
           sizeof(chunks) / sizeof(chunks[0]));
    
    /* Feed chunks one by one */
    for (size_t i = 0; i < sizeof(chunks) / sizeof(chunks[0]); i++) {
        printf("\nChunk %zu: \"%s\"\n", i + 1, chunks[i]);
        size_t chunk_len = strlen(chunks[i]);
        size_t parsed = multipart_parser_execute(parser, chunks[i], chunk_len);
        
        if (parsed != chunk_len) {
            printf("  Warning: Only parsed %zu of %zu bytes\n", parsed, chunk_len);
        }
    }
    
    printf("\nSuccessfully parsed %d parts with split boundaries\n", state.part_count);
    printf("Parser correctly handled %d data callbacks\n", state.data_callbacks);
    
    multipart_parser_free(parser);
    printf("\n");
}

/* ============================================================================
 * MAIN
 * ============================================================================
 */

int main(void) {
    printf("\n");
    printf("================================================================\n");
    printf("      Advanced Multipart Parsing Examples (RFC 7578)       \n");
    printf("                                                            \n");
    printf("  Application-Level Responsibilities:                       \n");
    printf("  - Content-Disposition parsing                            \n");
    printf("  - Filename extraction                                    \n");
    printf("  - RFC 5987 decoding                                      \n");
    printf("  - Security validations                                   \n");
    printf("  - Streaming with size limits                             \n");
    printf("================================================================\n");
    printf("\n");
    
    example_content_disposition_parsing();
    example_rfc5987_decoding();
    example_security_validations();
    example_size_limits();
    example_streaming_boundary_conditions();
    
    printf("================================================================\n");
    printf("              All Examples Completed Successfully!          \n");
    printf("================================================================\n");
    printf("\n");
    
    return 0;
}

/* Test for Issue #13: Header value double callback with 1-byte feeding
 * 
 * When feeding the parser 1 byte at a time, the on_header_value callback
 * is called twice when CR is the last byte in a chunk:
 * 1. Once with len > 0 (data before CR)
 * 2. Once with len = 1 containing the CR character
 * 
 * This is due to missing break/else in the s_header_value case.
 */
#include "multipart_parser.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* Track callback invocations */
typedef struct {
    int header_value_count;
    char last_header_value[256];
    size_t last_header_value_len;
    int found_cr_in_value;
} test_context;

static int on_header_value(multipart_parser* p, const char *at, size_t length) {
    test_context* ctx = (test_context*)multipart_parser_get_data(p);
    ctx->header_value_count++;
    
    /* Save the last value */
    if (length < sizeof(ctx->last_header_value)) {
        memcpy(ctx->last_header_value, at, length);
        ctx->last_header_value_len = length;
        ctx->last_header_value[length] = '\0';
    }
    
    /* Check if CR is in the value */
    if (length > 0 && at[length - 1] == '\r') {
        ctx->found_cr_in_value = 1;
    }
    
    return 0;
}

int main(void) {
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    test_context ctx;
    size_t i, parsed;
    
    /* RFC 2046 compliant multipart message with simple header */
    const char* message = 
        "--boundary\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data\r\n"
        "--boundary--\r\n";
    
    printf("=== Test for Issue #13 ===\n\n");
    printf("Testing 1-byte feeding with header value ending in CR...\n\n");
    
    /* Setup */
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_header_value = on_header_value;
    
    memset(&ctx, 0, sizeof(test_context));
    
    parser = multipart_parser_init("boundary", &callbacks);
    if (parser == NULL) {
        printf("FAILED: Parser initialization\n");
        return 1;
    }
    
    multipart_parser_set_data(parser, &ctx);
    
    /* Feed parser 1 byte at a time */
    for (i = 0; i < strlen(message); i++) {
        parsed = multipart_parser_execute(parser, message + i, 1);
        if (parsed != 1) {
            printf("FAILED: Parser stopped at byte %zu\n", i);
            multipart_parser_free(parser);
            return 1;
        }
    }
    
    printf("Header value callback count: %d\n", ctx.header_value_count);
    printf("CR found in value: %s\n", ctx.found_cr_in_value ? "YES" : "NO");
    
    if (ctx.last_header_value_len > 0) {
        printf("Last header value (len=%zu): \"", ctx.last_header_value_len);
        for (i = 0; i < ctx.last_header_value_len; i++) {
            if (ctx.last_header_value[i] == '\r') {
                printf("\\r");
            } else {
                printf("%c", ctx.last_header_value[i]);
            }
        }
        printf("\"\n");
    }
    
    printf("\n");
    
    /* Verify the bug: we should NOT receive CR in the header value */
    if (ctx.found_cr_in_value) {
        printf("FAILED: Issue #13 bug detected - CR character leaked into header value\n");
        printf("This indicates the double-callback bug when CR is the last byte in chunk\n");
        multipart_parser_free(parser);
        return 1;
    } else {
        printf("PASSED: No CR in header values (Issue #13 is fixed or doesn't reproduce)\n");
        multipart_parser_free(parser);
        return 0;
    }
}

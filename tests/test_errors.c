/* Error Handling Tests
 * Tests for error conditions and invalid inputs
 * Extracted from test.c Sections 4 and 5
 */
#include "test_common.h"


/* Track callback invocations */
typedef struct {
    int header_value_count;
    char last_header_value[256];
    size_t last_header_value_len;
    int found_cr_in_value;
} issue13_test_context;

static int on_header_value_issue13(multipart_parser* p, const char *at, size_t length) {
    issue13_test_context* ctx = (issue13_test_context*)multipart_parser_get_data(p);
    size_t i;
    ctx->header_value_count++;

    /* Save the last value */
    if (length <= sizeof(ctx->last_header_value) - 1) {
        memcpy(ctx->last_header_value, at, length);
        ctx->last_header_value_len = length;
        ctx->last_header_value[length] = '\0';
    }

    /* Check if CR is anywhere in the value */
    for (i = 0; i < length; i++) {
        if (at[i] == '\r') {
            ctx->found_cr_in_value = 1;
            break;
        }
    }

    return 0;
}

void test_issue13_header_value_cr(void) {
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    issue13_test_context ctx;
    size_t i, parsed;

    /* RFC 2046 compliant multipart message with simple header */
    const char* multipart_test_message =
        "--boundary\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data\r\n"
        "--boundary--\r\n";

    TEST_START("Issue #13: Header value CR with 1-byte feeding");

    /* Setup */
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_header_value = on_header_value_issue13;

    memset(&ctx, 0, sizeof(issue13_test_context));

    parser = multipart_parser_init("boundary", &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &ctx);

    /* Feed parser 1 byte at a time */
    for (i = 0; i < strlen(multipart_test_message); i++) {
        parsed = multipart_parser_execute(parser, multipart_test_message + i, 1);
        if (parsed != 1) {
            multipart_parser_free(parser);
            TEST_FAIL("Parser stopped during 1-byte feeding");
            return;
        }
    }

    /* Verify the bug: we should NOT receive CR in the header value */
    if (ctx.found_cr_in_value) {
        multipart_parser_free(parser);
        TEST_FAIL("CR character leaked into header value (Issue #13 bug)");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}



/* Test 19: Invalid header field character */
void test_error_invalid_header_field(void) {
    const char *boundary = "bound";
    /* Invalid character '@' in header name */
    const char *data =
        "--bound\r\n"
        "Content@Type: text/plain\r\n"
        "\r\n"
        "test";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Error: Invalid header field character");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed == strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Should have detected invalid header character");
        return;
    }

    if (multipart_parser_get_error(parser) != MPPE_INVALID_HEADER_FIELD) {
        multipart_parser_free(parser);
        TEST_FAIL("Wrong error code");
        return;
    }

    /* Check error message is not NULL */
    if (multipart_parser_get_error_message(parser) == NULL) {
        multipart_parser_free(parser);
        TEST_FAIL("Error message is NULL");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 20: Invalid boundary format */
void test_error_invalid_boundary(void) {
    const char *boundary = "bound";
    /* Missing second dash in final boundary */
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "test\r\n"
        "--bound-X";  /* Invalid: should be '--' */

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Error: Invalid boundary format");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed == strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Should have detected invalid boundary");
        return;
    }

    if (multipart_parser_get_error(parser) != MPPE_INVALID_BOUNDARY) {
        multipart_parser_free(parser);
        TEST_FAIL("Wrong error code");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 21: Callback pause */
int pause_callback(multipart_parser* p) {
    (void)p;
    return 1;  /* Pause parsing */
}

void test_error_callback_pause(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "test";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Error: Callback pause");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = pause_callback;

    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    /* Should pause before completing */
    if (parsed == strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Should have paused");
        return;
    }

    if (multipart_parser_get_error(parser) != MPPE_PAUSED) {
        multipart_parser_free(parser);
        TEST_FAIL("Wrong error code, expected MPPE_PAUSED");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 22: Multiple headers in one part */

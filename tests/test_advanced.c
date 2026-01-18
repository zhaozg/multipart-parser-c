/* Advanced Features Tests
 * Tests for advanced parser features like multiple headers, long values, etc.
 * Extracted from test.c (lines 1136-1311)
 */
#include "test_common.h"

void test_multiple_headers(void) {
    const char *boundary = "test";
    const char *data =
        "--test\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Disposition: form-data; name=\"field\"\r\n"
        "Content-Length: 5\r\n"
        "\r\n"
        "value\r\n"
        "--test--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Multiple headers in one part");

    /* Simple callback to count headers */
    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Failed to parse");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 23: Empty part data */
void test_empty_part_data(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "\r\n"  /* Empty data */
        "--bound--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Empty part data");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Failed to parse empty part");
        return;
    }

    if (multipart_parser_get_error(parser) != MPPE_OK) {
        multipart_parser_free(parser);
        TEST_FAIL("Got error on valid empty part");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 24: Very long header value */
void test_long_header_value(void) {
    const char *boundary = "bound";
    char data[2048];
    char long_value[1024];
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;
    int i;

    TEST_START("Very long header value");

    /* Generate long header value */
    for (i = 0; i < 1000; i++) {
        long_value[i] = 'A' + (i % 26);
    }
    long_value[1000] = '\0';

    /* Build multipart data with long header - use snprintf for safety */
    snprintf(data, sizeof(data), "--bound\r\nContent-Type: %s\r\n\r\ndata\r\n--bound--", long_value);

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Failed to parse long header");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 25: No data after final boundary */
void test_clean_end(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "test\r\n"
        "--bound--";  /* Clean end, no trailing data */

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Clean end after final boundary");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Failed to parse");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 26: Callback buffering with small buffer */
void test_callback_buffering(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "abcdefghijklmnopqrstuvwxyz0123456789\r\n"  /* 38 bytes of data */
        "--bound--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Callback buffering reduces callback frequency");

    /* Count callbacks */
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.buffer_size = 16;  /* Buffer 16 bytes before emitting */

    parser = multipart_parser_init(boundary, &callbacks);
    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Failed to parse with buffering");
        return;
    }

    if (multipart_parser_get_error(parser) != MPPE_OK) {
        multipart_parser_free(parser);
        TEST_FAIL("Got error with buffering enabled");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}


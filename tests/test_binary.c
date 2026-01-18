/* Binary Data Tests
 * Tests for handling binary data in multipart messages
 * Extracted from test.c Section 2
 */
#include "test_common.h"


/* Callback to count part data */
typedef struct {
    size_t total_bytes;
    int callback_count;
    int has_null_byte;
    int has_cr;
    int has_lf;
} binary_test_data;

int on_part_data_binary(multipart_parser* p, const char *at, size_t length) {
    binary_test_data *data = (binary_test_data*)multipart_parser_get_data(p);
    size_t i;

    data->total_bytes += length;
    data->callback_count++;

    for (i = 0; i < length; i++) {
        if (at[i] == '\0') data->has_null_byte = 1;
        if (at[i] == '\r') data->has_cr = 1;
        if (at[i] == '\n') data->has_lf = 1;
    }

    return 0;
}

/* Test 2.1: Binary data with CR characters - RFC 2046 compliant */
void test_binary_with_cr(void) {
    const char *boundary = "testbound";
    /* Binary data containing CR (0x0D) but not as part of CRLF */
    char data[100];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;

    TEST_START("Binary data with embedded CR (RFC 2046 compliant)");

    /* Build test data: boundary + headers + binary data with CR */
    pos = 0;
    memcpy(data + pos, "--testbound\r\n", 13);
    pos += 13;
    memcpy(data + pos, "Content-Type: application/octet-stream\r\n", 40);
    pos += 40;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add binary data: 0x01 0x02 0x0D 0x03 0x04
     * The 0x0D (CR) is not followed by LF, so per RFC 2046 it should be
     * treated as data, not as the start of a boundary marker. */
    data[pos++] = 0x01;
    data[pos++] = 0x02;
    data[pos++] = 0x0D; /* CR not followed by LF - valid binary data */
    data[pos++] = 0x03;
    data[pos++] = 0x04;

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on binary data with CR");
        return;
    }

    /* RFC 2046: Parser correctly handles isolated CR in binary data.
     * The implementation buffers CR and emits it as data if not followed by LF,
     * which is the correct RFC-compliant behavior. Previously marked as Issue #33,
     * but the issue was a test bug (incorrect memcpy length), not a parser bug. */
    if (test_data.callback_count == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("No data received - parser should handle isolated CR");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 2.2: Binary data with NULL bytes */
void test_binary_with_null(void) {
    const char *boundary = "nulltest";
    char data[100];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;

    TEST_START("Binary data with NULL bytes");

    /* Build test data with NULL bytes */
    pos = 0;
    memcpy(data + pos, "--nulltest\r\n", 12);
    pos += 12;
    memcpy(data + pos, "Content-Type: application/octet-stream\r\n", 40);
    pos += 40;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add binary data with NULL bytes: 0x01 0x00 0x02 0x00 0x03 */
    data[pos++] = 0x01;
    data[pos++] = 0x00; /* NULL byte */
    data[pos++] = 0x02;
    data[pos++] = 0x00; /* NULL byte */
    data[pos++] = 0x03;

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on binary data with NULL bytes");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 2.3: Binary data with boundary-like sequences */
void test_binary_with_boundary_like_data(void) {
    const char *boundary = "xyz123";
    char data[150];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;

    TEST_START("Binary data containing boundary-like sequences");

    /* Build test data */
    pos = 0;
    memcpy(data + pos, "--xyz123\r\n", 10);
    pos += 10;
    memcpy(data + pos, "Content-Type: application/octet-stream\r\n", 40);
    pos += 40;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add data that looks like boundary but isn't: "xyz" (partial match) */
    memcpy(data + pos, "xyz", 3);
    pos += 3;
    /* Add more binary data */
    data[pos++] = (char)0xFF;
    data[pos++] = (char)0xFE;

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on boundary-like data");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 2.4: High-byte binary data (0x80-0xFF) */
void test_binary_high_bytes(void) {
    const char *boundary = "highbyte";
    char data[100];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;
    int i;

    TEST_START("Binary data with high bytes (0x80-0xFF)");

    /* Build test data */
    pos = 0;
    memcpy(data + pos, "--highbyte\r\n", 12);
    pos += 12;
    memcpy(data + pos, "Content-Type: image/jpeg\r\n", 26);
    pos += 26;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add high bytes typical in JPEG/PNG headers */
    for (i = 0; i < 10; i++) {
        data[pos++] = (char)(0x80 + i);
    }

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on high-byte data");
        return;
    }

    if (test_data.callback_count == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("No callbacks received");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 2.5: All zeros binary data */
void test_binary_all_zeros(void) {
    const char *boundary = "zeros";
    char data[100];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;
    int i;

    TEST_START("Binary data with all zero bytes");

    /* Build test data */
    pos = 0;
    memcpy(data + pos, "--zeros\r\n", 9);
    pos += 9;
    memcpy(data + pos, "Content-Type: application/octet-stream\r\n", 40);
    pos += 40;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add 10 zero bytes */
    for (i = 0; i < 10; i++) {
        data[pos++] = 0x00;
    }

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on all-zeros data");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 2.6: CRLF sequences in binary data */
void test_binary_with_crlf_sequences(void) {
    const char *boundary = "crlftest";
    char data[100];
    size_t pos;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    binary_test_data test_data;
    size_t parsed;

    TEST_START("Binary data with multiple CRLF sequences");

    /* Build test data */
    pos = 0;
    memcpy(data + pos, "--crlftest\r\n", 12);
    pos += 12;
    memcpy(data + pos, "Content-Type: application/octet-stream\r\n", 40);
    pos += 40;
    memcpy(data + pos, "\r\n", 2);
    pos += 2;
    /* Add binary data with CRLF: 0x01 \r\n 0x02 \r\n 0x03 */
    data[pos++] = 0x01;
    data[pos++] = 0x0D;
    data[pos++] = 0x0A;
    data[pos++] = 0x02;
    data[pos++] = 0x0D;
    data[pos++] = 0x0A;
    data[pos++] = 0x03;

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_binary;

    memset(&test_data, 0, sizeof(binary_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, pos);

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed on CRLF sequences");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}


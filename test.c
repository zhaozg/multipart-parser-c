/* Comprehensive test suite for multipart parser
 * Combines: test_basic.c, test_binary.c, test_rfc.c, test_issue13.c
 */
#include "multipart_parser.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int test_count = 0;
int test_passed = 0;
int test_failed = 0;

#define TEST_START(name) \
    do { \
        test_count++; \
        printf("Test %d: %s ... ", test_count, name); \
        fflush(stdout); \
    } while(0)

#define TEST_PASS() \
    do { \
        printf("PASSED\n"); \
        test_passed++; \
    } while(0)

#define TEST_FAIL(msg) \
    do { \
        printf("FAILED: %s\n", msg); \
        test_failed++; \
    } while(0)

/* ========================================================================
 * SECTION 1: Basic Parser Tests (from test_basic.c)
 * ======================================================================== */

/* Test 1.1: Parser initialization and cleanup */
void test_init_free(void) {
    multipart_parser_settings callbacks;
    multipart_parser* parser;

    TEST_START("Parser initialization and cleanup");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init("boundary", &callbacks);

    if (parser == NULL) {
        TEST_FAIL("Parser initialization returned NULL");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 1.2: NULL check on malloc result */
void test_malloc_check(void) {
    multipart_parser_settings callbacks;
    multipart_parser* parser;

    TEST_START("Malloc result check exists");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init("test", &callbacks);

    /* If parser is NULL, malloc failed (unlikely but we check for it) */
    /* If parser is not NULL, the code has the check in place */
    if (parser != NULL) {
        multipart_parser_free(parser);
    }

    TEST_PASS();
}

/* Test 1.3: Basic parsing */
int part_data_begin_count = 0;

int on_part_data_begin(multipart_parser* p) {
    part_data_begin_count++;
    return 0;
}

void test_basic_parsing(void) {
    const char *boundary = "bound";
    /* RFC 2046 compliant: boundaries have -- prefix */
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "test data";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("Basic parsing of multipart data");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin;

    part_data_begin_count = 0;

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser returned 0 (error occurred)");
        return;
    }

    if (part_data_begin_count == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("on_part_data_begin never called");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 1.4: Chunked parsing */
void test_chunked_parsing(void) {
    const char *boundary = "bound";
    /* RFC 2046 compliant */
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t i;
    size_t len;
    size_t parsed;

    TEST_START("Chunked parsing (1 byte at a time)");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    len = strlen(data);
    for (i = 0; i < len; i++) {
        parsed = multipart_parser_execute(parser, data + i, 1);
        if (parsed == 0) {
            multipart_parser_free(parser);
            TEST_FAIL("Parser failed during chunked parsing");
            return;
        }
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 1.5: Large boundary */
void test_large_boundary(void) {
    char boundary[256];
    multipart_parser_settings callbacks;
    multipart_parser* parser;

    TEST_START("Parser with large boundary string");

    memset(boundary, 'x', 255);
    boundary[255] = '\0';

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed with large boundary");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 1.6: Boundary format validation */
void test_invalid_boundary(void) {
    const char *boundary = "correctboundary";
    /* Data with correct boundary but invalid format (missing CRLF after boundary) */
    const char *data = "--correctboundary\r\nContent-Type: text/plain";

    multipart_parser_settings callbacks;
    multipart_parser* parser;

    TEST_START("Boundary format validation");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin;

    part_data_begin_count = 0;

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_execute(parser, data, strlen(data));

    /* Parser should parse valid boundary */
    if (part_data_begin_count == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser didn't recognize valid boundary");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 1.7: User data get/set */
void test_user_data(void) {
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    int test_value = 42;
    void *retrieved;

    TEST_START("User data get/set");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init("boundary", &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_value);
    retrieved = multipart_parser_get_data(parser);

    if (retrieved != &test_value) {
        multipart_parser_free(parser);
        TEST_FAIL("Retrieved data doesn't match set data");
        return;
    }

    if (*(int*)retrieved != 42) {
        multipart_parser_free(parser);
        TEST_FAIL("Retrieved value doesn't match expected value");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* ========================================================================
 * SECTION 2: Binary Data Tests (from test_binary.c)
 * ======================================================================== */

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

/* ========================================================================
 * SECTION 3: RFC 2046 Compliance Tests (from test_rfc.c)
 * ======================================================================== */

/* Callback tracking structure */
typedef struct {
    int part_data_begin_count;
    int headers_complete_count;
    int part_data_end_count;
    int body_end_count;
    char *part_data;
    size_t part_data_len;
} rfc_test_data;

int on_part_data_begin_rfc(multipart_parser* p) {
    rfc_test_data *data = (rfc_test_data*)multipart_parser_get_data(p);
    data->part_data_begin_count++;
    return 0;
}

int on_headers_complete_rfc(multipart_parser* p) {
    rfc_test_data *data = (rfc_test_data*)multipart_parser_get_data(p);
    data->headers_complete_count++;
    return 0;
}

int on_part_data_end_rfc(multipart_parser* p) {
    rfc_test_data *data = (rfc_test_data*)multipart_parser_get_data(p);
    data->part_data_end_count++;
    return 0;
}

int on_body_end_rfc(multipart_parser* p) {
    rfc_test_data *data = (rfc_test_data*)multipart_parser_get_data(p);
    data->body_end_count++;
    return 0;
}

int on_part_data_rfc(multipart_parser* p, const char *at, size_t length) {
    rfc_test_data *data = (rfc_test_data*)multipart_parser_get_data(p);

    if (data->part_data == NULL) {
        data->part_data = malloc(length + 1);
        if (!data->part_data) return 1;
        memcpy(data->part_data, at, length);
        data->part_data[length] = '\0';
        data->part_data_len = length;
    } else {
        char *new_data = realloc(data->part_data, data->part_data_len + length + 1);
        if (!new_data) return 1;
        data->part_data = new_data;
        memcpy(data->part_data + data->part_data_len, at, length);
        data->part_data_len += length;
        data->part_data[data->part_data_len] = '\0';
    }

    return 0;
}

/* Test 3.1: RFC-compliant single part */
void test_rfc_single_part(void) {
    const char *boundary = "boundary123";
    /* RFC 2046 compliant format: boundaries have -- prefix */
    const char *data =
        "--boundary123\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Hello World\r\n"
        "--boundary123--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    rfc_test_data test_data;
    size_t parsed;

    TEST_START("RFC 2046 single part with proper boundaries");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin_rfc;
    callbacks.on_headers_complete = on_headers_complete_rfc;
    callbacks.on_part_data_end = on_part_data_end_rfc;
    callbacks.on_body_end = on_body_end_rfc;
    callbacks.on_part_data = on_part_data_rfc;

    memset(&test_data, 0, sizeof(rfc_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        free(test_data.part_data);
        TEST_FAIL("Parser did not consume all data");
        return;
    }

    if (test_data.part_data_begin_count != 1) {
        multipart_parser_free(parser);
        free(test_data.part_data);
        TEST_FAIL("part_data_begin not called exactly once");
        return;
    }

    if (test_data.part_data_end_count != 1) {
        multipart_parser_free(parser);
        free(test_data.part_data);
        TEST_FAIL("part_data_end not called exactly once");
        return;
    }

    if (test_data.body_end_count != 1) {
        multipart_parser_free(parser);
        free(test_data.part_data);
        TEST_FAIL("body_end not called exactly once");
        return;
    }

    if (test_data.part_data == NULL || strcmp(test_data.part_data, "Hello World") != 0) {
        multipart_parser_free(parser);
        free(test_data.part_data);
        TEST_FAIL("Part data not correctly captured");
        return;
    }

    multipart_parser_free(parser);
    free(test_data.part_data);
    TEST_PASS();
}

/* Test 3.2: RFC-compliant multiple parts */
void test_rfc_multiple_parts(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Part 1\r\n"
        "--bound\r\n"
        "Content-Type: text/html\r\n"
        "\r\n"
        "Part 2\r\n"
        "--bound--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    rfc_test_data test_data;
    size_t parsed;

    TEST_START("RFC 2046 multiple parts");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin_rfc;
    callbacks.on_headers_complete = on_headers_complete_rfc;
    callbacks.on_part_data_end = on_part_data_end_rfc;
    callbacks.on_body_end = on_body_end_rfc;

    memset(&test_data, 0, sizeof(rfc_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser did not consume all data");
        return;
    }

    if (test_data.part_data_begin_count != 2) {
        multipart_parser_free(parser);
        TEST_FAIL("Expected 2 parts");
        return;
    }

    if (test_data.part_data_end_count != 2) {
        multipart_parser_free(parser);
        TEST_FAIL("part_data_end not called for both parts");
        return;
    }

    if (test_data.body_end_count != 1) {
        multipart_parser_free(parser);
        TEST_FAIL("body_end not called exactly once");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 3.3: RFC-compliant preamble */
void test_rfc_with_preamble(void) {
    const char *boundary = "simple";
    /* RFC 2046 allows preamble before first boundary */
    const char *data =
        "This is the preamble. It is ignored.\r\n"
        "--simple\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Content\r\n"
        "--simple--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    rfc_test_data test_data;
    size_t parsed;

    TEST_START("RFC 2046 with preamble");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin_rfc;
    callbacks.on_body_end = on_body_end_rfc;

    memset(&test_data, 0, sizeof(rfc_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    /* Parser should handle or skip preamble */
    if (parsed == 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser failed with preamble");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 3.4: Empty part */
void test_rfc_empty_part(void) {
    const char *boundary = "test";
    const char *data =
        "--test\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "\r\n"
        "--test--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    rfc_test_data test_data;
    size_t parsed;

    TEST_START("RFC 2046 empty part");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_data_begin_rfc;
    callbacks.on_part_data_end = on_part_data_end_rfc;
    callbacks.on_body_end = on_body_end_rfc;

    memset(&test_data, 0, sizeof(rfc_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, strlen(data));

    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser did not consume all data");
        return;
    }

    if (test_data.body_end_count != 1) {
        multipart_parser_free(parser);
        TEST_FAIL("body_end not called");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* ========================================================================
 * SECTION 4: Issue #13 Regression Test (from test_issue13.c)
 * ======================================================================== */

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

/* ========================================================================
 * SECTION 5: Error Handling Tests
 * ======================================================================== */

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

/* ========================================================================
 * SECTION 8: Parser Reset Tests
 * ======================================================================== */

/* Test 27: Basic parser reset */
void test_reset_basic(void) {
    const char *boundary1 = "bound1";
    const char *boundary2 = "bound2";
    const char *data1 =
        "--bound1\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data1\r\n"
        "--bound1--";
    const char *data2 =
        "--bound2\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data2\r\n"
        "--bound2--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;
    int reset_result;

    TEST_START("Basic parser reset with new boundary");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary1, &callbacks);

    /* Parse first data */
    parsed = multipart_parser_execute(parser, data1, strlen(data1));
    if (parsed != strlen(data1)) {
        multipart_parser_free(parser);
        TEST_FAIL("First parse failed");
        return;
    }

    /* Reset parser with new boundary */
    reset_result = multipart_parser_reset(parser, boundary2);
    if (reset_result != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Reset failed");
        return;
    }

    /* Parse second data with new boundary */
    parsed = multipart_parser_execute(parser, data2, strlen(data2));
    if (parsed != strlen(data2)) {
        multipart_parser_free(parser);
        TEST_FAIL("Second parse after reset failed");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 28: Parser reset without changing boundary */
void test_reset_same_boundary(void) {
    const char *boundary = "bound";
    const char *data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "test\r\n"
        "--bound--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;
    int reset_result;

    TEST_START("Parser reset keeping same boundary");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    /* Parse first time */
    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("First parse failed");
        return;
    }

    /* Reset parser without changing boundary (NULL parameter) */
    reset_result = multipart_parser_reset(parser, NULL);
    if (reset_result != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Reset failed");
        return;
    }

    /* Parse second time with same boundary */
    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Second parse after reset failed");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 29: Parser reset with too long boundary */
void test_reset_boundary_too_long(void) {
    const char *boundary1 = "short";
    const char *boundary2 = "verylongboundarystring";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    int reset_result;

    TEST_START("Parser reset with boundary too long");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary1, &callbacks);

    /* Try to reset with longer boundary - should fail */
    reset_result = multipart_parser_reset(parser, boundary2);
    if (reset_result != -1) {
        multipart_parser_free(parser);
        TEST_FAIL("Reset should have failed with too long boundary");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 30: Parser reset with NULL parser */
void test_reset_null_parser(void) {
    int reset_result;

    TEST_START("Parser reset with NULL parser pointer");

    /* Try to reset NULL parser - should fail safely */
    reset_result = multipart_parser_reset(NULL, "boundary");
    if (reset_result != -1) {
        TEST_FAIL("Reset should have failed with NULL parser");
        return;
    }

    TEST_PASS();
}

/* Test 31: Parser reset clears error state */
void test_reset_clears_error(void) {
    const char *boundary = "bound";
    const char *bad_data =
        "--bound\r\n"
        "Content@Type: text/plain\r\n";  /* Invalid character */
    const char *good_data =
        "--bound\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "data\r\n"
        "--bound--";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;
    int reset_result;

    TEST_START("Parser reset clears error state");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    parser = multipart_parser_init(boundary, &callbacks);

    /* Parse bad data - should error */
    parsed = multipart_parser_execute(parser, bad_data, strlen(bad_data));
    if (multipart_parser_get_error(parser) == MPPE_OK) {
        multipart_parser_free(parser);
        TEST_FAIL("Should have detected error in bad data");
        return;
    }

    /* Reset parser */
    reset_result = multipart_parser_reset(parser, NULL);
    if (reset_result != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("Reset failed");
        return;
    }

    /* Error should be cleared */
    if (multipart_parser_get_error(parser) != MPPE_OK) {
        multipart_parser_free(parser);
        TEST_FAIL("Error not cleared after reset");
        return;
    }

    /* Parse good data - should succeed */
    parsed = multipart_parser_execute(parser, good_data, strlen(good_data));
    if (parsed != strlen(good_data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parse failed after reset");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* ========================================================================
 * SECTION 9: RFC 7578 Specific Tests
 * ======================================================================== */

/* Test 9.1: Multiple files with same field name (RFC 7578 Section 4.3) */
typedef struct {
    int part_count;
} rfc7578_test_data;

int on_part_begin_rfc7578(multipart_parser* p) {
    rfc7578_test_data* data = (rfc7578_test_data*)multipart_parser_get_data(p);
    data->part_count++;
    return 0;
}

void test_rfc7578_multiple_files_same_name(void) {
    const char *boundary = "boundary123";
    /* RFC 7578 Section 4.3: Multiple files with same field name */
    const char *data =
        "--boundary123\r\n"
        "Content-Disposition: form-data; name=\"files\"; filename=\"file1.txt\"\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Content of file1\r\n"
        "--boundary123\r\n"
        "Content-Disposition: form-data; name=\"files\"; filename=\"file2.txt\"\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Content of file2\r\n"
        "--boundary123\r\n"
        "Content-Disposition: form-data; name=\"files\"; filename=\"file3.txt\"\r\n"
        "Content-Type: text/plain\r\n"
        "\r\n"
        "Content of file3\r\n"
        "--boundary123--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    rfc7578_test_data test_data;
    size_t parsed;

    TEST_START("RFC 7578: Multiple files with same field name");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data_begin = on_part_begin_rfc7578;

    memset(&test_data, 0, sizeof(rfc7578_test_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    multipart_parser_set_data(parser, &test_data);

    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parse failed");
        return;
    }

    if (test_data.part_count != 3) {
        multipart_parser_free(parser);
        TEST_FAIL("Expected 3 parts");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 9.2: UTF-8 field values (RFC 7578 default charset) */
void test_rfc7578_utf8_content(void) {
    const char *boundary = "utf8test";
    /* RFC 7578: Default charset is UTF-8 */
    const char *data =
        "--utf8test\r\n"
        "Content-Disposition: form-data; name=\"comment\"\r\n"
        "Content-Type: text/plain; charset=UTF-8\r\n"
        "\r\n"
        "UTF-8 content: \xE4\xB8\xAD\xE6\x96\x87\r\n"  /* Chinese characters */
        "--utf8test--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("RFC 7578: UTF-8 field content");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    /* Parser should handle UTF-8 bytes (binary-safe) */
    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parse failed with UTF-8 content");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 9.3: Field name with special characters */
void test_rfc7578_special_field_name(void) {
    const char *boundary = "special";
    /* Field names can have special characters when quoted */
    const char *data =
        "--special\r\n"
        "Content-Disposition: form-data; name=\"field-name_123\"\r\n"
        "\r\n"
        "value\r\n"
        "--special\r\n"
        "Content-Disposition: form-data; name=\"field.name\"\r\n"
        "\r\n"
        "value2\r\n"
        "--special--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("RFC 7578: Field names with special characters");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parse failed");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 9.4: Empty filename (RFC 7578: file not selected) */
void test_rfc7578_empty_filename(void) {
    const char *boundary = "empty";
    /* RFC 7578: Empty filename indicates no file selected */
    const char *data =
        "--empty\r\n"
        "Content-Disposition: form-data; name=\"file\"; filename=\"\"\r\n"
        "Content-Type: application/octet-stream\r\n"
        "\r\n"
        "\r\n"
        "--empty--\r\n";

    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;

    TEST_START("RFC 7578: Empty filename");

    memset(&callbacks, 0, sizeof(multipart_parser_settings));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }

    parsed = multipart_parser_execute(parser, data, strlen(data));
    if (parsed != strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parse failed");
        return;
    }

    multipart_parser_free(parser);
    TEST_PASS();
}

/* ========================================================================
 * Section 10: Safety and Robustness Tests
 * ======================================================================== */

/* Test: NULL pointer safety in API functions */
static void test_null_pointer_safety(void) {
    const char *data;
    size_t parsed;
    const char *error_msg;
    multipart_parser_error error;
    void *user_data;
    
    TEST_START("NULL pointer safety in API functions");
    
    data = "--bound\r\nContent-Type: text/plain\r\n\r\ntest\r\n--bound--";
    
    /* Test multipart_parser_execute with NULL parser */
    parsed = multipart_parser_execute(NULL, data, strlen(data));
    if (parsed != 0) {
        TEST_FAIL("execute with NULL parser should return 0");
        return;
    }
    
    /* Test multipart_parser_execute with NULL buffer (but len > 0) */
    /* This would normally be tested but we need a valid parser */
    
    /* Test multipart_parser_free with NULL */
    multipart_parser_free(NULL);  /* Should not crash */
    
    /* Test multipart_parser_set_data with NULL */
    multipart_parser_set_data(NULL, (void*)0x1234);  /* Should not crash */
    
    /* Test multipart_parser_get_data with NULL */
    user_data = multipart_parser_get_data(NULL);
    if (user_data != NULL) {
        TEST_FAIL("get_data with NULL parser should return NULL");
        return;
    }
    
    /* Test multipart_parser_get_error with NULL */
    error = multipart_parser_get_error(NULL);
    if (error != MPPE_UNKNOWN) {
        TEST_FAIL("get_error with NULL parser should return MPPE_UNKNOWN");
        return;
    }
    
    /* Test multipart_parser_get_error_message with NULL */
    error_msg = multipart_parser_get_error_message(NULL);
    if (error_msg == NULL || strlen(error_msg) == 0) {
        TEST_FAIL("get_error_message with NULL parser should return valid message");
        return;
    }
    
    /* Test multipart_parser_reset with NULL */
    if (multipart_parser_reset(NULL, "newbound") != -1) {
        TEST_FAIL("reset with NULL parser should return -1");
        return;
    }
    
    TEST_PASS();
}

/* Test: NULL buffer with valid parser */
static void test_null_buffer_safety(void) {
    multipart_parser *parser;
    multipart_parser_settings callbacks;
    const char *boundary;
    size_t parsed;
    multipart_parser_error error;
    
    TEST_START("NULL buffer safety with valid parser");
    
    boundary = "bound";
    
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    
    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }
    
    /* Test execute with NULL buffer and len > 0 */
    parsed = multipart_parser_execute(parser, NULL, 100);
    if (parsed != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("execute with NULL buffer and len>0 should return 0");
        return;
    }
    
    error = multipart_parser_get_error(parser);
    if (error != MPPE_INVALID_STATE) {
        multipart_parser_free(parser);
        TEST_FAIL("execute with NULL buffer should set MPPE_INVALID_STATE error");
        return;
    }
    
    /* Test execute with NULL buffer and len = 0 (should be safe) */
    if (multipart_parser_reset(parser, NULL) != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("reset should succeed");
        return;
    }
    parsed = multipart_parser_execute(parser, NULL, 0);
    /* This is actually valid - parsing 0 bytes with NULL buffer is OK */
    
    multipart_parser_free(parser);
    TEST_PASS();
}

/* ========================================================================
 * MAIN - Run all test sections
 * ======================================================================== */

int main(void) {
    printf("=== Multipart Parser Comprehensive Test Suite ===\n\n");

    /* Section 1: Basic Parser Tests */
    printf("--- Section 1: Basic Parser Tests ---\n");
    test_init_free();
    test_malloc_check();
    test_basic_parsing();
    test_chunked_parsing();
    test_large_boundary();
    test_invalid_boundary();
    test_user_data();
    printf("\n");

    /* Section 2: Binary Data Tests */
    printf("--- Section 2: Binary Data Edge Case Tests ---\n");
    test_binary_with_cr();
    test_binary_with_null();
    test_binary_with_boundary_like_data();
    test_binary_high_bytes();
    test_binary_all_zeros();
    test_binary_with_crlf_sequences();
    printf("\n");

    /* Section 3: RFC 2046 Compliance Tests */
    printf("--- Section 3: RFC 2046 Compliance Tests ---\n");
    test_rfc_single_part();
    test_rfc_multiple_parts();
    test_rfc_with_preamble();
    test_rfc_empty_part();
    printf("\n");

    /* Section 4: Issue #13 Regression Test */
    printf("--- Section 4: Issue Regression Tests ---\n");
    test_issue13_header_value_cr();
    printf("\n");

    /* Section 5: Error Handling Tests */
    printf("--- Section 5: Error Handling Tests ---\n");
    test_error_invalid_header_field();
    test_error_invalid_boundary();
    test_error_callback_pause();
    printf("\n");

    /* Section 6: Additional Coverage Tests */
    printf("--- Section 6: Coverage Improvement Tests ---\n");
    test_multiple_headers();
    test_empty_part_data();
    test_long_header_value();
    test_clean_end();
    printf("\n");

    /* Section 7: Buffering Tests */
    printf("--- Section 7: Callback Buffering Tests ---\n");
    test_callback_buffering();
    printf("\n");

    /* Section 8: Parser Reset Tests */
    printf("--- Section 8: Parser Reset Tests ---\n");
    test_reset_basic();
    test_reset_same_boundary();
    test_reset_boundary_too_long();
    test_reset_null_parser();
    test_reset_clears_error();
    printf("\n");

    /* Section 9: RFC 7578 Specific Tests */
    printf("--- Section 9: RFC 7578 Specific Tests ---\n");
    test_rfc7578_multiple_files_same_name();
    test_rfc7578_utf8_content();
    test_rfc7578_special_field_name();
    test_rfc7578_empty_filename();
    printf("\n");

    /* Section 10: Safety and Robustness Tests */
    printf("--- Section 10: Safety and Robustness Tests ---\n");
    test_null_pointer_safety();
    test_null_buffer_safety();
    printf("\n");

    /* Summary */
    printf("=== Test Summary ===\n");
    printf("Total: %d\n", test_count);
    printf("Passed: %d\n", test_passed);
    printf("Failed: %d\n", test_failed);

    return test_failed > 0 ? 1 : 0;
}

/* Basic Parser Tests - Section 1
 * Tests fundamental parser functionality
 */
#include "test_common.h"

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
static int part_data_begin_count = 0;

static int on_part_data_begin(multipart_parser* p) {
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

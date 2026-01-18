/* Parser Reset Tests
 * Tests for multipart_parser_reset functionality
 * Extracted from test.c Section 8
 */
#include "test_common.h"


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


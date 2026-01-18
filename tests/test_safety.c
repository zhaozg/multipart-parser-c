/* Safety and Robustness Tests
 * Tests for parser safety with edge cases and malformed input
 * Extracted from test.c Section 10
 */
#include "test_common.h"


/* Test: NULL pointer safety in API functions */
void test_null_pointer_safety(void) {
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
void test_null_buffer_safety(void) {
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
    /* Reset to clear the error state from previous test (keeps same boundary) */
    if (multipart_parser_reset(parser, NULL) != 0) {
        multipart_parser_free(parser);
        TEST_FAIL("reset should succeed");
        return;
    }
    parsed = multipart_parser_execute(parser, NULL, 0);
    /* Parsing 0 bytes with NULL buffer is valid and should succeed */
    
    multipart_parser_free(parser);
    TEST_PASS();
}


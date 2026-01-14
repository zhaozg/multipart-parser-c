/* RFC 2046 compliance tests for multipart parser
 * Tests that the parser correctly handles RFC-compliant boundary format
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

/* Test 1: RFC-compliant single part */
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

/* Test 2: RFC-compliant multiple parts */
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

/* Test 3: RFC-compliant preamble */
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

/* Test 4: Empty part */
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

int main(void) {
    printf("=== RFC 2046 Compliance Tests ===\n\n");
    
    test_rfc_single_part();
    test_rfc_multiple_parts();
    test_rfc_with_preamble();
    test_rfc_empty_part();
    
    printf("\n=== Test Summary ===\n");
    printf("Total: %d\n", test_count);
    printf("Passed: %d\n", test_passed);
    printf("Failed: %d\n", test_failed);
    
    return test_failed > 0 ? 1 : 0;
}

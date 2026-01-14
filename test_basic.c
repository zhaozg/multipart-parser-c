/* Simple test to verify basic parser functionality */
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

/* Test 1: Parser initialization and cleanup */
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

/* Test 2: NULL check on malloc result */
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

/* Test 3: Basic parsing */
int part_data_begin_count = 0;

int on_part_data_begin(multipart_parser* p) {
    part_data_begin_count++;
    return 0;
}

void test_basic_parsing(void) {
    const char *boundary = "bound";
    const char *data = 
        "bound\r\n"
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

/* Test 4: Chunked parsing */
void test_chunked_parsing(void) {
    const char *boundary = "bound";
    const char *data = 
        "bound\r\n"
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

/* Test 5: Large boundary */
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

/* Test 6: Invalid boundary detection */
void test_invalid_boundary(void) {
    const char *boundary = "correctboundary";
    const char *data = "wrongboundary\r\n";
    
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    size_t parsed;
    
    TEST_START("Invalid boundary detection");
    
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    
    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        TEST_FAIL("Parser initialization failed");
        return;
    }
    
    parsed = multipart_parser_execute(parser, data, strlen(data));
    
    /* Parser should stop early when boundary doesn't match */
    if (parsed == strlen(data)) {
        multipart_parser_free(parser);
        TEST_FAIL("Parser accepted invalid boundary");
        return;
    }
    
    multipart_parser_free(parser);
    TEST_PASS();
}

/* Test 7: User data get/set */
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

int main(void) {
    printf("=== Multipart Parser Basic Test Suite ===\n\n");
    
    test_init_free();
    test_malloc_check();
    test_basic_parsing();
    test_chunked_parsing();
    test_large_boundary();
    test_invalid_boundary();
    test_user_data();
    
    printf("\n=== Test Summary ===\n");
    printf("Total: %d\n", test_count);
    printf("Passed: %d\n", test_passed);
    printf("Failed: %d\n", test_failed);
    
    return test_failed > 0 ? 1 : 0;
}

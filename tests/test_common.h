/* Common definitions and helpers for multipart parser test suite
 * Shared across all test modules
 */
#ifndef TEST_COMMON_H
#define TEST_COMMON_H

#include "../multipart_parser.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* Global test counters - defined in test_main.c */
extern int test_count;
extern int test_passed;
extern int test_failed;

/* Test macros */
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

/* Test function declarations - implemented in respective test files */
/* Section 1: Basic Parser Tests */
void test_init_free(void);
void test_malloc_check(void);
void test_basic_parsing(void);
void test_chunked_parsing(void);
void test_large_boundary(void);
void test_invalid_boundary(void);
void test_user_data(void);

/* Section 2: Binary Data Tests */
void test_binary_with_cr(void);
void test_binary_with_null(void);
void test_binary_with_boundary_like_data(void);
void test_binary_high_bytes(void);
void test_binary_all_zeros(void);
void test_binary_with_crlf_sequences(void);

/* Section 3 & 9: RFC Compliance Tests */
void test_rfc_single_part(void);
void test_rfc_multiple_parts(void);
void test_rfc_with_preamble(void);
void test_rfc_empty_part(void);
void test_rfc7578_multiple_files_same_name(void);
void test_rfc7578_utf8_content(void);
void test_rfc7578_special_field_name(void);
void test_rfc7578_empty_filename(void);

/* Section 4 & 5: Error Handling Tests */
void test_issue13_header_value_cr(void);
void test_error_invalid_header_field(void);
void test_error_invalid_boundary(void);
void test_error_callback_pause(void);

/* Section 6 & 7: Advanced Tests */
void test_multiple_headers(void);
void test_empty_part_data(void);
void test_long_header_value(void);
void test_clean_end(void);
void test_callback_buffering(void);

/* Section 8: Parser Reset Tests */
void test_reset_basic(void);
void test_reset_same_boundary(void);
void test_reset_boundary_too_long(void);
void test_reset_null_parser(void);
void test_reset_clears_error(void);

/* Section 10: Safety Tests */
void test_null_pointer_safety(void);
void test_null_buffer_safety(void);

#endif /* TEST_COMMON_H */

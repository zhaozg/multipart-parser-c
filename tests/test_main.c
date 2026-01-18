/* Main Test Runner
 * Runs all test suites in organized order
 */
#include "test_common.h"

/* Global test counters */
int test_count = 0;
int test_passed = 0;
int test_failed = 0;

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

/* RFC Compliance Tests
 * Tests for RFC 2046 and RFC 7578 compliance
 * Extracted from test.c Sections 3 and 9
 */
#include "test_common.h"


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


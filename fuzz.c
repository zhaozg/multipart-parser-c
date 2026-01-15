/* Fuzzing harness for multipart parser
 * Compatible with AFL++ and libFuzzer
 */
#include "multipart_parser.h"
#include <stdint.h>
#include <stddef.h>
#include <string.h>

/* Fuzzing callbacks - minimal implementation */
static int fuzz_on_part_data(multipart_parser* p, const char *at, size_t length) {
    (void)p;
    (void)at;
    (void)length;
    return 0;
}

static int fuzz_on_header_field(multipart_parser* p, const char *at, size_t length) {
    (void)p;
    (void)at;
    (void)length;
    return 0;
}

static int fuzz_on_header_value(multipart_parser* p, const char *at, size_t length) {
    (void)p;
    (void)at;
    (void)length;
    return 0;
}

static int fuzz_on_part_data_begin(multipart_parser* p) {
    (void)p;
    return 0;
}

static int fuzz_on_headers_complete(multipart_parser* p) {
    (void)p;
    return 0;
}

static int fuzz_on_part_data_end(multipart_parser* p) {
    (void)p;
    return 0;
}

static int fuzz_on_body_end(multipart_parser* p) {
    (void)p;
    return 0;
}

#ifdef __AFL_FUZZ_TESTCASE_LEN
/* AFL++ persistent mode */
__AFL_FUZZ_INIT();
#endif

#ifdef LIBFUZZER
/* libFuzzer entry point */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
#else
/* AFL++ or standalone mode */
int main(void) {
#ifdef __AFL_FUZZ_TESTCASE_LEN
    /* AFL++ persistent mode */
    __AFL_INIT();
    unsigned char *data = __AFL_FUZZ_TESTCASE_BUF;
    while (__AFL_LOOP(10000)) {
        size_t size = __AFL_FUZZ_TESTCASE_LEN;
#else
    /* Standalone mode - read from stdin */
    unsigned char buffer[65536];
    size_t size = fread(buffer, 1, sizeof(buffer), stdin);
    unsigned char *data = buffer;
#endif
#endif

    if (size < 1 || size > 100000) {
#ifdef LIBFUZZER
        return 0;
#else
        goto cleanup;
#endif
    }

    /* Extract boundary from first part of input (up to 70 bytes max) */
    size_t boundary_len = size > 70 ? 70 : size;

    /* Ensure boundary is reasonable length (1-70 bytes) */
    if (boundary_len < 1) boundary_len = 1;
    if (boundary_len > size / 2) boundary_len = size / 2;

    char boundary[71];
    memcpy(boundary, data, boundary_len);
    boundary[boundary_len] = '\0';

    /* Replace any null bytes in boundary */
    size_t i;
    for (i = 0; i < boundary_len; i++) {
        if (boundary[i] == '\0') {
            boundary[i] = 'X';
        }
    }

    /* Setup callbacks */
    multipart_parser_settings callbacks;
    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = fuzz_on_part_data;
    callbacks.on_header_field = fuzz_on_header_field;
    callbacks.on_header_value = fuzz_on_header_value;
    callbacks.on_part_data_begin = fuzz_on_part_data_begin;
    callbacks.on_headers_complete = fuzz_on_headers_complete;
    callbacks.on_part_data_end = fuzz_on_part_data_end;
    callbacks.on_body_end = fuzz_on_body_end;

    /* Initialize parser */
    multipart_parser* parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
#ifdef LIBFUZZER
        return 0;
#else
        goto cleanup;
#endif
    }

    /* Parse the data (use data after boundary as content) */
    const unsigned char *content = data + boundary_len;
    size_t content_size = size - boundary_len;

    if (content_size > 0) {
        multipart_parser_execute(parser, (const char*)content, content_size);
    }

    /* Cleanup */
    multipart_parser_free(parser);

#ifdef LIBFUZZER
    return 0;
#else
cleanup:
#ifdef __AFL_FUZZ_TESTCASE_LEN
    }
#endif
    return 0;
}
#endif

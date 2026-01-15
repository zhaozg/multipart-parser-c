/* Performance benchmark tests for multipart parser
 * Measures throughput and efficiency
 */
#include "multipart_parser.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

/* Simple callback that just counts */
typedef struct {
    size_t total_bytes;
    int part_count;
    int callback_count;  /* Track number of callbacks for granularity metrics */
} perf_data;

int on_part_data_perf(multipart_parser* p, const char *at, size_t length) {
    perf_data *data = (perf_data*)multipart_parser_get_data(p);
    data->total_bytes += length;
    data->callback_count++;  /* Track callback frequency */
    return 0;
}

int on_part_begin_perf(multipart_parser* p) {
    perf_data *data = (perf_data*)multipart_parser_get_data(p);
    data->part_count++;
    return 0;
}

/* Helper to build multipart data */
size_t build_multipart_data(char *buffer, const char *boundary,
                            const char *content, size_t content_len,
                            int num_parts) {
    size_t pos = 0;
    int i;

    for (i = 0; i < num_parts; i++) {
        /* Boundary */
        memcpy(buffer + pos, boundary, strlen(boundary));
        pos += strlen(boundary);
        buffer[pos++] = '\r';
        buffer[pos++] = '\n';

        /* Headers */
        memcpy(buffer + pos, "Content-Type: text/plain\r\n\r\n", 28);
        pos += 28;

        /* Content */
        memcpy(buffer + pos, content, content_len);
        pos += content_len;

        if (i < num_parts - 1) {
            /* Part separator */
            buffer[pos++] = '\r';
            buffer[pos++] = '\n';
            buffer[pos++] = '-';
            buffer[pos++] = '-';
        }
    }

    return pos;
}

/* Benchmark 1: Small message throughput */
void benchmark_small_messages(void) {
    const char *boundary = "bound";
    const char *content = "Hello World";
    char data[1000];
    size_t data_len;
    multipart_parser_settings callbacks;
    perf_data pdata;
    clock_t start, end;
    double cpu_time;
    int iterations = 10000;
    int i;

    printf("\n=== Benchmark 1: Small Messages (10KB content) ===\n");

    data_len = build_multipart_data(data, boundary, content, strlen(content), 1);

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_perf;
    callbacks.on_part_data_begin = on_part_begin_perf;

    memset(&pdata, 0, sizeof(perf_data));

    start = clock();

    for (i = 0; i < iterations; i++) {
        multipart_parser* parser = multipart_parser_init(boundary, &callbacks);
        if (parser == NULL) continue;

        multipart_parser_set_data(parser, &pdata);
        multipart_parser_execute(parser, data, data_len);
        multipart_parser_free(parser);
    }

    end = clock();
    cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;

    printf("Iterations: %d\n", iterations);
    printf("Time: %.3f seconds\n", cpu_time);
    printf("Messages/sec: %.0f\n", iterations / cpu_time);
    printf("Throughput: %.2f MB/s\n",
           (iterations * data_len) / (cpu_time * 1024 * 1024));
    printf("Avg callbacks/msg: %.1f\n", (double)pdata.callback_count / iterations);
    printf("Avg callback size: %.1f bytes\n",
           pdata.total_bytes > 0 ? (double)pdata.total_bytes / pdata.callback_count : 0);
}

/* Benchmark 2: Large message parsing */
void benchmark_large_message(void) {
    const char *boundary = "boundary123";
    char *data;
    char *content;
    size_t content_len = 1024 * 100; /* 100KB content */
    size_t data_len;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    perf_data pdata;
    clock_t start, end;
    double cpu_time;
    size_t i;

    printf("\n=== Benchmark 2: Large Message (100KB content) ===\n");

    /* Allocate buffers */
    content = (char*)malloc(content_len);
    if (content == NULL) {
        printf("Memory allocation failed\n");
        return;
    }

    /* Fill with test data */
    for (i = 0; i < content_len; i++) {
        content[i] = (char)('A' + (i % 26));
    }

    /* Allocate data buffer (content + overhead) */
    data = (char*)malloc(content_len + 1000);
    if (data == NULL) {
        free(content);
        printf("Memory allocation failed\n");
        return;
    }

    data_len = build_multipart_data(data, boundary, content, content_len, 1);

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_perf;
    callbacks.on_part_data_begin = on_part_begin_perf;

    memset(&pdata, 0, sizeof(perf_data));

    parser = multipart_parser_init(boundary, &callbacks);
    if (parser == NULL) {
        free(content);
        free(data);
        printf("Parser initialization failed\n");
        return;
    }

    multipart_parser_set_data(parser, &pdata);

    start = clock();
    multipart_parser_execute(parser, data, data_len);
    end = clock();

    cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;

    printf("Message size: %zu bytes\n", data_len);
    printf("Parse time: %.6f seconds\n", cpu_time);
    printf("Throughput: %.2f MB/s\n",
           data_len / (cpu_time * 1024 * 1024));
    printf("Total callbacks: %d\n", pdata.callback_count);
    printf("Avg callback size: %.1f bytes\n",
           pdata.callback_count > 0 ? (double)pdata.total_bytes / pdata.callback_count : 0);

    multipart_parser_free(parser);
    free(content);
    free(data);
}

/* Benchmark 3: Chunked parsing efficiency */
void benchmark_chunked_parsing(void) {
    const char *boundary = "chunk";
    const char *content = "Test data for chunked parsing benchmark.";
    char data[500];
    size_t data_len;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    perf_data pdata;
    clock_t start, end;
    double cpu_time;
    size_t chunk_sizes[] = {1, 4, 16, 64, 256};
    size_t num_chunk_sizes = sizeof(chunk_sizes) / sizeof(chunk_sizes[0]);
    size_t i;
    size_t offset;

    printf("\n=== Benchmark 3: Chunked Parsing Efficiency ===\n");

    data_len = build_multipart_data(data, boundary, content, strlen(content), 1);

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_perf;
    callbacks.on_part_data_begin = on_part_begin_perf;

    for (i = 0; i < num_chunk_sizes; i++) {
        size_t chunk_size = chunk_sizes[i];
        int iterations = 5000;
        int iter;

        memset(&pdata, 0, sizeof(perf_data));

        start = clock();

        for (iter = 0; iter < iterations; iter++) {
            parser = multipart_parser_init(boundary, &callbacks);
            if (parser == NULL) continue;

            multipart_parser_set_data(parser, &pdata);

            /* Parse in chunks */
            offset = 0;
            while (offset < data_len) {
                size_t to_parse = chunk_size;
                if (offset + to_parse > data_len) {
                    to_parse = data_len - offset;
                }
                multipart_parser_execute(parser, data + offset, to_parse);
                offset += to_parse;
            }

            multipart_parser_free(parser);
        }

        end = clock();
        cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;

        printf("Chunk size: %4zu bytes - Time: %.3f sec - Rate: %.0f parses/sec - Callbacks: %d\n",
               chunk_size, cpu_time, iterations / cpu_time, pdata.callback_count);
    }
}

/* Benchmark 4: Multiple parts parsing */
void benchmark_multiple_parts(void) {
    const char *boundary = "multipart";
    const char *content = "Part content data.";
    char *data;
    size_t data_len;
    multipart_parser_settings callbacks;
    multipart_parser* parser;
    perf_data pdata;
    clock_t start, end;
    double cpu_time;
    int num_parts_array[] = {1, 5, 10, 20, 50};
    size_t num_tests = sizeof(num_parts_array) / sizeof(num_parts_array[0]);
    size_t i;

    printf("\n=== Benchmark 4: Multiple Parts Performance ===\n");

    /* Allocate buffer for large multipart message */
    data = (char*)malloc(100000);
    if (data == NULL) {
        printf("Memory allocation failed\n");
        return;
    }

    memset(&callbacks, 0, sizeof(multipart_parser_settings));
    callbacks.on_part_data = on_part_data_perf;
    callbacks.on_part_data_begin = on_part_begin_perf;

    for (i = 0; i < num_tests; i++) {
        int num_parts = num_parts_array[i];
        int iterations = 1000;
        int iter;

        data_len = build_multipart_data(data, boundary, content,
                                       strlen(content), num_parts);

        memset(&pdata, 0, sizeof(perf_data));

        start = clock();

        for (iter = 0; iter < iterations; iter++) {
            parser = multipart_parser_init(boundary, &callbacks);
            if (parser == NULL) continue;

            multipart_parser_set_data(parser, &pdata);
            multipart_parser_execute(parser, data, data_len);
            multipart_parser_free(parser);
        }

        end = clock();
        cpu_time = ((double)(end - start)) / CLOCKS_PER_SEC;

        printf("Parts: %2d - Size: %5zu bytes - Time: %.3f sec - Rate: %.0f parses/sec\n",
               num_parts, data_len, cpu_time, iterations / cpu_time);
    }

    free(data);
}

int main(void) {
    printf("=== Multipart Parser Performance Benchmarks ===\n");
    printf("Note: Results depend on system performance and load\n");

    benchmark_small_messages();
    benchmark_large_message();
    benchmark_chunked_parsing();
    benchmark_multiple_parts();

    printf("\n=== Benchmarks Complete ===\n");
    return 0;
}

CFLAGS?=-std=c89 -ansi -pedantic -O4 -Wall -fPIC
ASAN_FLAGS=-std=c89 -ansi -pedantic -g -O1 -fsanitize=address -fno-omit-frame-pointer -Wall
UBSAN_FLAGS=-std=c89 -ansi -pedantic -g -O1 -fsanitize=undefined -fno-omit-frame-pointer -Wall
COVERAGE_FLAGS=-std=c89 -ansi -pedantic -g -O0 --coverage -fprofile-arcs -ftest-coverage -Wall
PROFILE_FLAGS=-std=c89 -ansi -pedantic -g -O2 -Wall

default: multipart_parser.o

multipart_parser.o: multipart_parser.c multipart_parser.h

solib: multipart_parser.o
	$(CC) -shared -Wl,-soname,libmultipart.so -o libmultipart.so multipart_parser.o

test: test_basic test_binary test_rfc test_issue13
	@echo "Running basic tests..."
	./test_basic
	@echo ""
	@echo "Running binary data tests..."
	./test_binary
	@echo ""
	@echo "Running RFC 2046 compliance tests..."
	./test_rfc
	@echo ""
	@echo "Running Issue #13 regression test..."
	./test_issue13

test_basic: test_basic.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_basic test_basic.c multipart_parser.c

test_binary: test_binary.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_binary test_binary.c multipart_parser.c

test_rfc: test_rfc.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_rfc test_rfc.c multipart_parser.c

test_issue13: test_issue13.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_issue13 test_issue13.c multipart_parser.c

test_performance: test_performance.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_performance test_performance.c multipart_parser.c

benchmark: test_performance
	@echo "Running performance benchmarks..."
	./test_performance

clean:
	rm -f *.o *.so test_basic test_binary test_rfc test_performance test_issue13
	rm -f *.gcov *.gcda *.gcno coverage.info coverage.txt coverage.xml
	rm -rf coverage-html
	rm -f callgrind.out* cachegrind.out* massif.out*
	rm -f valgrind-*.log

# AddressSanitizer targets
test-asan: clean
	CFLAGS="$(ASAN_FLAGS)" $(MAKE) test_basic test_binary test_rfc test_issue13
	@echo "Running tests with AddressSanitizer..."
	ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1 ./test_basic
	ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1 ./test_binary
	ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1 ./test_rfc
	ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1 ./test_issue13

# UndefinedBehaviorSanitizer targets
test-ubsan: clean
	CFLAGS="$(UBSAN_FLAGS)" $(MAKE) test_basic test_binary test_rfc test_issue13
	@echo "Running tests with UndefinedBehaviorSanitizer..."
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./test_basic
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./test_binary
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./test_rfc
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./test_issue13

# Valgrind memcheck targets
test-valgrind: clean
	CFLAGS="-std=c89 -ansi -pedantic -g -O0 -Wall" $(MAKE) test_basic test_binary test_rfc test_issue13
	@echo "Running tests with Valgrind memcheck..."
	valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 --suppressions=.valgrind.suppressions ./test_basic
	valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 --suppressions=.valgrind.suppressions ./test_binary
	valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 --suppressions=.valgrind.suppressions ./test_rfc
	valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 --suppressions=.valgrind.suppressions ./test_issue13

# Code coverage targets
coverage: clean
	CFLAGS="$(COVERAGE_FLAGS)" $(MAKE) test_basic test_binary test_rfc test_issue13
	@echo "Running tests for coverage..."
	./test_basic
	./test_binary
	./test_rfc
	./test_issue13
	@echo "Generating coverage report..."
	gcov -o . multipart_parser.c test_basic.c test_binary.c test_rfc.c test_issue13.c || true
	@echo ""
	@echo "Coverage files generated:"
	@ls -lh *.gcov 2>/dev/null || echo "  (gcov files generated)"
	@echo ""
	@echo "To view coverage for multipart_parser.c:"
	@echo "  less multipart_parser.c.gcov"
	@echo ""
	@if command -v lcov >/dev/null 2>&1; then \
		echo "Generating LCOV report..."; \
		lcov --capture --directory . --output-file coverage.info 2>/dev/null || true; \
		lcov --remove coverage.info '/usr/*' --output-file coverage.info 2>/dev/null || true; \
		lcov --list coverage.info 2>/dev/null || true; \
		if command -v genhtml >/dev/null 2>&1; then \
			genhtml coverage.info --output-directory coverage-html 2>/dev/null || true; \
			echo "HTML report: coverage-html/index.html"; \
		fi; \
	fi
	@if command -v gcovr >/dev/null 2>&1; then \
		echo "Generating gcovr report..."; \
		gcovr --txt -o coverage.txt 2>/dev/null || true; \
		gcovr --xml -o coverage.xml 2>/dev/null || true; \
		cat coverage.txt 2>/dev/null || true; \
	fi

# Performance profiling with Callgrind
profile-callgrind: clean
	CFLAGS="$(PROFILE_FLAGS)" $(MAKE) test_performance
	@echo "Running Callgrind profiling..."
	valgrind --tool=callgrind --callgrind-out-file=callgrind.out --dump-instr=yes --collect-jumps=yes ./test_performance
	@echo "Generating Callgrind report..."
	callgrind_annotate callgrind.out --auto=yes > callgrind-report.txt
	@echo ""
	@echo "Top functions by self cost:"
	@callgrind_annotate callgrind.out --auto=yes --threshold=0.1 | head -50

# Cache profiling with Cachegrind
profile-cachegrind: clean
	CFLAGS="$(PROFILE_FLAGS)" $(MAKE) test_performance
	@echo "Running Cachegrind profiling..."
	valgrind --tool=cachegrind --cachegrind-out-file=cachegrind.out ./test_performance
	@echo "Generating Cachegrind report..."
	cg_annotate cachegrind.out --auto=yes > cachegrind-report.txt
	@echo ""
	@echo "Cache performance summary:"
	@cg_annotate cachegrind.out --auto=yes | head -30

# Run all sanitizer and analysis tools
test-all: test test-asan test-ubsan test-valgrind coverage
	@echo ""
	@echo "========================================"
	@echo "All tests and analysis completed!"
	@echo "========================================"

.PHONY: test test-asan test-ubsan test-valgrind coverage profile-callgrind profile-cachegrind test-all clean benchmark

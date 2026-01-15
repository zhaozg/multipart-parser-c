CFLAGS?=-std=c89 -ansi -pedantic -O4 -Wall -fPIC
# Optimized build with Link-Time Optimization
CFLAGS_LTO?=-std=c89 -ansi -pedantic -O3 -flto -Wall -fPIC
LDFLAGS_LTO?=-flto
ASAN_FLAGS=-std=c89 -ansi -pedantic -g -O1 -fsanitize=address -fno-omit-frame-pointer -Wall
UBSAN_FLAGS=-std=c89 -ansi -pedantic -g -O1 -fsanitize=undefined -fno-omit-frame-pointer -Wall
COVERAGE_FLAGS=-std=c89 -ansi -pedantic -g -O0 --coverage -fprofile-arcs -ftest-coverage -Wall
PROFILE_FLAGS=-std=c89 -ansi -pedantic -g -O2 -Wall
FUZZ_FLAGS=-std=c89 -ansi -pedantic -g -O1 -fsanitize=address,fuzzer -fno-omit-frame-pointer -Wall

default: multipart_parser.o

multipart_parser.o: multipart_parser.c multipart_parser.h

solib: multipart_parser.o
	$(CC) -shared -Wl,-soname,libmultipart.so -o libmultipart.so multipart_parser.o

test: test_bin
	@echo "Running comprehensive test suite..."
	./test

test_bin: test.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test test.c multipart_parser.c

benchmark_bin: benchmark.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o benchmark benchmark.c multipart_parser.c

benchmark: benchmark_bin
	@echo "Running performance benchmarks..."
	./benchmark

clean:
	rm -f *.o *.so test benchmark fuzz-afl fuzz-libfuzzer
	rm -f *.gcov *.gcda *.gcno coverage.info coverage.txt coverage.xml
	rm -f *.gcno coverage.info coverage.txt coverage.xml
	rm -rf coverage-html
	rm -f callgrind.out* cachegrind.out* massif.out*
	rm -f valgrind-*.log
	rm -rf fuzz-corpus fuzz-findings

# AddressSanitizer targets
test-asan: clean
	CFLAGS="$(ASAN_FLAGS)" $(MAKE) test_bin
	@echo "Running tests with AddressSanitizer..."
	ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:strict_init_order=1 ./test

# UndefinedBehaviorSanitizer targets
test-ubsan: clean
	CFLAGS="$(UBSAN_FLAGS)" $(MAKE) test_bin
	@echo "Running tests with UndefinedBehaviorSanitizer..."
	UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./test

# Valgrind memcheck targets
test-valgrind: clean
	CFLAGS="-std=c89 -ansi -pedantic -g -O0 -Wall" $(MAKE) test_bin
	@echo "Running tests with Valgrind memcheck..."
	valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=1 --suppressions=.valgrind.suppressions ./test

# Code coverage targets
coverage: clean
	CFLAGS="$(COVERAGE_FLAGS)" $(MAKE) test_bin
	@echo "Running tests for coverage..."
	./test
	@echo "Generating coverage report..."
	gcov -o . multipart_parser.c test.c || true
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
	CFLAGS="$(PROFILE_FLAGS)" $(MAKE) benchmark_bin
	@echo "Running Callgrind profiling..."
	valgrind --tool=callgrind --callgrind-out-file=callgrind.out --dump-instr=yes --collect-jumps=yes ./benchmark
	@echo "Generating Callgrind report..."
	callgrind_annotate callgrind.out --auto=yes > callgrind-report.txt
	@echo ""
	@echo "Top functions by self cost:"
	@callgrind_annotate callgrind.out --auto=yes --threshold=0.1 | head -50

# Cache profiling with Cachegrind
profile-cachegrind: clean
	CFLAGS="$(PROFILE_FLAGS)" $(MAKE) benchmark_bin
	@echo "Running Cachegrind profiling..."
	valgrind --tool=cachegrind --cachegrind-out-file=cachegrind.out ./benchmark
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

# Link-Time Optimization build
build-lto: clean
	@echo "Building with Link-Time Optimization..."
	$(CC) $(CFLAGS_LTO) $(LDFLAGS_LTO) -o test test.c multipart_parser.c
	$(CC) $(CFLAGS_LTO) $(LDFLAGS_LTO) -o benchmark benchmark.c multipart_parser.c

# Profile-Guided Optimization
pgo-generate: clean
	@echo "Building for PGO profiling..."
	$(CC) $(CFLAGS) -fprofile-generate -o benchmark benchmark.c multipart_parser.c
	@echo "Running benchmark to generate profile..."
	./benchmark
	@echo "Profile data generated. Run 'make pgo-use' to build optimized binary."

pgo-use:
	@echo "Building with PGO profile data..."
	$(CC) $(CFLAGS) -fprofile-use -o benchmark benchmark.c multipart_parser.c
	@echo "Optimized binary ready. Run './benchmark' to test."

# Fuzzing targets
fuzz-afl: fuzz.c multipart_parser.c multipart_parser.h
	@echo "Building AFL++ fuzzer..."
	@if command -v afl-clang-fast >/dev/null 2>&1; then \
		afl-clang-fast -std=c89 -g -O2 -o fuzz-afl fuzz.c multipart_parser.c; \
		echo "AFL++ fuzzer built successfully!"; \
		echo "Run: afl-fuzz -i fuzz-corpus -o fuzz-findings ./fuzz-afl"; \
	else \
		echo "AFL++ not found. Install with: sudo apt-get install afl++"; \
		exit 1; \
	fi

fuzz-libfuzzer: fuzz.c multipart_parser.c multipart_parser.h
	@echo "Building libFuzzer harness..."
	@if command -v clang >/dev/null 2>&1; then \
		clang -DLIBFUZZER $(FUZZ_FLAGS) -o fuzz-libfuzzer fuzz.c multipart_parser.c; \
		echo "libFuzzer harness built successfully!"; \
		echo "Run: ./fuzz-libfuzzer fuzz-corpus -max_total_time=60"; \
	else \
		echo "clang not found. Install with: sudo apt-get install clang"; \
		exit 1; \
	fi

fuzz-corpus:
	@echo "Creating initial fuzzing corpus..."
	@mkdir -p fuzz-corpus
	@echo '--boundary\r\nContent-Type: text/plain\r\n\r\ntest' > fuzz-corpus/test1.txt
	@echo '--bound\r\nContent-Disposition: form-data; name="field"\r\n\r\nvalue\r\n--bound--' > fuzz-corpus/test2.txt
	@/bin/echo -e '--xyz\r\nContent-Type: application/octet-stream\r\n\r\n\x00\x01\x02\r\n--xyz--' > fuzz-corpus/test3.txt
	@echo "Corpus created in fuzz-corpus/"

fuzz-test: fuzz-corpus fuzz-libfuzzer
	@echo "Running quick fuzz test (60 seconds)..."
	./fuzz-libfuzzer fuzz-corpus -max_total_time=60 -print_final_stats=1

.PHONY: test test-asan test-ubsan test-valgrind coverage profile-callgrind profile-cachegrind test-all clean benchmark build-lto pgo-generate pgo-use fuzz-afl fuzz-libfuzzer fuzz-corpus fuzz-test

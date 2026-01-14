CFLAGS?=-std=c89 -ansi -pedantic -O4 -Wall -fPIC 

default: multipart_parser.o

multipart_parser.o: multipart_parser.c multipart_parser.h

solib: multipart_parser.o
	$(CC) -shared -Wl,-soname,libmultipart.so -o libmultipart.so multipart_parser.o

test: test_basic test_binary
	@echo "Running basic tests..."
	./test_basic
	@echo ""
	@echo "Running binary data tests..."
	./test_binary

test_basic: test_basic.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_basic test_basic.c multipart_parser.c

test_binary: test_binary.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_binary test_binary.c multipart_parser.c

test_performance: test_performance.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_performance test_performance.c multipart_parser.c

benchmark: test_performance
	@echo "Running performance benchmarks..."
	./test_performance

clean:
	rm -f *.o *.so test_basic test_binary test_performance

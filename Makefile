CFLAGS?=-std=c89 -ansi -pedantic -O4 -Wall -fPIC 

default: multipart_parser.o

multipart_parser.o: multipart_parser.c multipart_parser.h

solib: multipart_parser.o
	$(CC) -shared -Wl,-soname,libmultipart.so -o libmultipart.so multipart_parser.o

test: test_basic
	./test_basic

test_basic: test_basic.c multipart_parser.c multipart_parser.h
	$(CC) $(CFLAGS) -o test_basic test_basic.c multipart_parser.c

clean:
	rm -f *.o *.so test_basic

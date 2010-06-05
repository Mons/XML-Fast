#!/bin/sh

CFLAGS="-O2 -g -ggdb -fno-common -ffast-math -W -Wall -Wshadow -Wcast-align -Wredundant-decls -Wbad-function-cast -Wcast-qual -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes"

gcc -c -I. xmlfast.c && \
gcc -c -I. test2.c && \
gcc xmlfast.o test2.o  -o test && ./test


#gcc -o test test2.c && \
#./test


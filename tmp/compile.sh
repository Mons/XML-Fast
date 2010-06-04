#!/bin/sh

CFLAGS="-O2 -g -ggdb -fno-common -ffast-math -W -Wall -Wshadow -Wcast-align -Wredundant-decls -Wbad-function-cast -Wcast-qual -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes"

gcc -o test test.c && \
#gcc $CFLAGS -o test test.c
./test


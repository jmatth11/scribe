INCLUDES=-I../../header/
LIBS=-L../../zig-out/lib/
CFLAGS=-std=c11 -Wall -Wextra -lscribe
TARGET=simple_example

.PHONY: all
all:
	gcc main.c $(LIBS) $(INCLUDES) $(CFLAGS) -o $(TARGET)

.PHONY: run
run: all
	./$(TARGET)

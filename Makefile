.PHONY: all
all:
	zig build -Doptimize=ReleaseSafe

.PHONY: clean
clean:
	@rm -rf zig-out

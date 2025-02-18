build: zig_game

clean:
	rm zig_game

zig_game:
	zig build --release=safe
	mv zig-out/bin/zig_game .
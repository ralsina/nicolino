all: bin
clean:
	rm -rf bin shard.lock lib
test:
	bin/ameba --fix
bin:
	shards build -d --error-trace
release:
	shards build --release
	strip bin/nicolino
mt:
	shards build -d
	strip bin/nicolino
mt-release:
	shards build --release
	strip bin/nicolino
static:
	./build_static.sh
lint:
	bin/ameba --fix

changelog:
	git cliff -o --sort=newest


.PHONY: all bin clean test release mt mt-release static lint changelog

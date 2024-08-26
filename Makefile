all: bin
clean:
	rm /bin/nicolino shard.lock lib -rf
test: ameba --all --fix
bin:
	shards build -d --error-trace
release:
	shards build --release
	strip bin/nicolino
mt:
	shards build -Dpreview_mt -d
	strip bin/nicolino
mt-release:
	shards build --release -Dpreview_mt
	strip bin/nicolino
lint:
	bin/ameba --all --fix

.PHONY: clean all test bin lint

all: bin
clean:
	rm -rf bin shard.lock lib
test:
	bin/ameba --all --except Documentation/DocumentationAdmonition --fix
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
lint:
	bin/ameba --all --fix

changelog:
	git cliff -o --sort=newest


.PHONY: all bin clean test release mt mt-release lint changelog

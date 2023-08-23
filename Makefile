all: bin
clean:
	rm /bin/nicolino shard.lock lib -rf
test: ameba --all --fix
bin:
	shards build -d
	cat .rucksack >> bin/nicolino
release:
	shards build --release -d
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt:
	shards build -Dpreview_mt -d
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt-release:
	shards build --release -Dpreview_mt -d
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
.PHONY: clean all test bin

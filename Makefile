all: bin
clean: 
	rm /bin/nicolino shard.lock lib -rf
test: ameba --all --fix
bin:
	shards build -d
	cat .rucksack >> bin/nicolino
release:
	shards build --release
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt:
	shards build -Dpreview_mt
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt-release:
	shards build --release -Dpreview_mt
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
.PHONY: clean all test bin

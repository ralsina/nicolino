all: bin
clean: rm /bin/nicolino
test: ameba --all --fix
bin:
	shards build
	cat .rucksack >> bin/nicolino
release:
	shards build -Dpreview_mt --release
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
.PHONY: clean all test bin

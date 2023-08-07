all: bin
clean: rm /bin/nicolino
test: ameba --all --fix
bin:
	shards build
	cat .rucksack >> bin/nicolino
release:
	shards build --release
	cat .rucksack >> bin/nic
.PHONY: clean all test bin

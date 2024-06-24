all: bin
clean:
	rm /bin/nicolino shard.lock lib -rf
test: ameba --all --fix
bin:
	shards build -v -d
	cat .rucksack >> bin/nicolino
release:
	shards build -v --release
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt:
	shards build -v -Dpreview_mt -d
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
mt-release:
	shards build -v --release -Dpreview_mt
	strip bin/nicolino
	cat .rucksack >> bin/nicolino
lint:
	bin/ameba --all --fix
static:
	# Sadly doesn't work because there is no static libdiscount in alpine
	docker build . -t nicolino-builder
	docker run -ti -v .:/src -w /src crystal shards build --static


.PHONY: clean all test bin lint

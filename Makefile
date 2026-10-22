PORT ?= 3000
BIND_ADDRESS := 127.0.0.1

.PHONY: setup run

setup:
	./script/bootstrap

run: setup
	./bin/dev --binding $(BIND_ADDRESS) --port $(PORT)

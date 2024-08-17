.PHONY: ready lint test

ready: lint test

lint:
	luacheck valid.lua
	luacheck --std=min+busted tests.lua

test:
	busted tests.lua

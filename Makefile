.PHONY: build check format lint release-test run test

format:
	swift format --in-place --parallel --recursive Package.swift Sources Tests

lint:
	swift format lint --strict --parallel --recursive Package.swift Sources Tests

build:
	swift build

test:
	swift test --parallel

release-test:
	swift build -c release
	swift test -c release --parallel

check:
	swift format lint --strict --parallel --recursive Package.swift Sources Tests
	swift build
	swift test --parallel
	swift build -c release
	swift test -c release --parallel

run:
	swift run PoofDemo

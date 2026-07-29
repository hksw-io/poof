.PHONY: build check format lint media release-test run test

SWIFT_PATHS = Package.swift Sources Tests \
	Tools/PoofMediaGenerator/Package.swift \
	Tools/PoofMediaGenerator/Sources \
	Tools/PoofMediaGenerator/Tests

format:
	swift format --in-place --parallel --recursive $(SWIFT_PATHS)

lint:
	swift format lint --strict --parallel --recursive $(SWIFT_PATHS)

build:
	swift build

test:
	swift test --parallel

release-test:
	swift build -c release
	swift test -c release --parallel

check:
	swift format lint --strict --parallel --recursive $(SWIFT_PATHS)
	swift build
	swift test --parallel
	swift build -c release
	swift test -c release --parallel
	swift test --package-path Tools/PoofMediaGenerator --parallel

media:
	swift run --package-path Tools/PoofMediaGenerator -c release \
		PoofMediaGenerator --output Documentation/Media

run:
	swift run PoofDemo

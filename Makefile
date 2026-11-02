# Developer commands. CI only runs `build` and `test`: signing material never leaves this Mac.
.DEFAULT_GOAL := help
.PHONY: help setup-signing build test check-core bundle run stop

EXE := Downtab
APP := build/$(EXE).app
SIGNING_DIR := .signing
KEYCHAIN := $(CURDIR)/$(SIGNING_DIR)/downtab.keychain-db
KEYCHAIN_PASSWORD := downtab

# Workaround: with Swift 6.4's default build system, any `swift build` before `swift test` drops the
# Swift Testing macro plugin path ("plugin for module 'TestingMacros' not found"). Passing it explicitly
# on every build and test keeps the build configuration identical across commands.
TESTING_PLUGINS = $(shell dirname "$$(xcrun -f swift)")/../lib/swift/host/plugins/testing
SWIFT_FLAGS = -Xswiftc -plugin-path -Xswiftc "$(TESTING_PLUGINS)"

help:
	@echo "make setup-signing   once per clone: create the self-signed certificate in a dedicated keychain"
	@echo "make build           debug build"
	@echo "make test            check the core boundary, then run the tests"
	@echo "make check-core      fail if the Switcher core imports anything but Foundation or loads private APIs"
	@echo "make bundle          release build, assemble and sign $(APP)"
	@echo "make run             bundle, then launch the app (quitting a running instance first)"
	@echo "make stop            quit the running app"

setup-signing:
	@scripts/setup-signing.sh $(SIGNING_DIR) $(KEYCHAIN_PASSWORD)

build:
	swift build $(SWIFT_FLAGS)

test: check-core
	swift test $(SWIFT_FLAGS)

check-core:
	@scripts/check-core.sh

bundle:
	@test -f "$(KEYCHAIN)" || { echo "signing missing: run make setup-signing"; exit 1; }
	swift build -c release --product $(EXE) $(SWIFT_FLAGS)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp "$$(swift build -c release --show-bin-path)/$(EXE)" "$(APP)/Contents/MacOS/$(EXE)"
	cp App/Info.plist "$(APP)/Contents/Info.plist"
	@security unlock-keychain -p $(KEYCHAIN_PASSWORD) "$(KEYCHAIN)"
	codesign --force --keychain "$(KEYCHAIN)" -s "$$(openssl x509 -in $(SIGNING_DIR)/cert.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)" "$(APP)"
	@codesign --verify "$(APP)" && codesign -d -r- "$(APP)" 2>&1 | grep designated

# Quit first: `open` would reactivate a still-exiting instance instead of launching the new build.
run: stop bundle
	@# Launch through LaunchServices so macOS attributes permissions to the bundle, not to the terminal.
	@open "$(APP)"
	@echo "running: look for the Downtab icon in the menu bar"

stop:
	@if pkill -x $(EXE); then \
		while pgrep -x $(EXE) >/dev/null; do sleep 0.1; done; echo stopped; \
	else echo "not running"; fi

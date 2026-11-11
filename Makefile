# Developer commands. CI only runs `build` and `test`: signing material never leaves this Mac.
.DEFAULT_GOAL := help
.PHONY: help setup-signing build test check-core test-versioning lint format icon bundle package run stop smoke restore restore-status \
	version release ship

EXE := Downtab
APP := build/$(EXE).app
RESTORE := build/EmergencyRestore
ZIP := build/$(EXE).zip
# Signing material lives in the main checkout, shared by its worktrees: one certificate, one Accessibility grant.
MAIN_CHECKOUT := $(shell common=$$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
	&& dirname "$$common" || pwd)
SIGNING_DIR := $(MAIN_CHECKOUT)/.signing
KEYCHAIN := $(SIGNING_DIR)/downtab.keychain-db
KEYCHAIN_PASSWORD := downtab
SIGN = codesign --force --keychain "$(KEYCHAIN)" \
	-s "$$(openssl x509 -in $(SIGNING_DIR)/cert.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"

# Workaround: with Swift 6.4's default build system, any `swift build` before `swift test` drops the
# Swift Testing macro plugin path ("plugin for module 'TestingMacros' not found"). Passing it explicitly
# on every build and test keeps the build configuration identical across commands.
TESTING_PLUGINS = $(shell dirname "$$(xcrun -f swift)")/../lib/swift/host/plugins/testing
SWIFT_FLAGS = -Xswiftc -plugin-path -Xswiftc "$(TESTING_PLUGINS)"

help:
	@echo "make setup-signing   once per clone: create the self-signed certificate in a dedicated keychain"
	@echo "make build           debug build of the app and of Emergency restore"
	@echo "make test            check the core boundary and lint, then run the tests"
	@echo "make check-core      fail if the Switcher core imports anything but Foundation or loads private APIs"
	@echo "make lint            swift-format check (.swift-format) and SwiftLint (.swiftlint.yml); any violation fails"
	@echo "make format          rewrite sources with swift-format"
	@echo "make icon            render App/Icon/*.svg into App/AppIcon.icns (needs rsvg-convert)"
	@echo "make bundle          release build, assemble and sign $(APP), copy and sign Emergency restore as $(RESTORE)"
	@echo "make package         bundle, then zip $(APP) and $(RESTORE) as $(ZIP) (Downtab/ folder), checking signatures"
	@echo "make run             bundle, then launch the app (quitting a running instance first)"
	@echo "make stop            quit the running app"
	@echo "make restore         Emergency restore: turn native ⌘Tab and ⌘\` back on, after a forced kill or a crash"
	@echo "make restore-status  show whether native ⌘Tab and ⌘\` are on, changing nothing"
	@echo "make smoke           bundle, launch, post ⌥/⌥Tab/⌥⇧Tab/⌥\`/⌥⇧\`/Esc, fail on a crash; must pass before closing an issue that touches the app"
	@echo "make version V=X.Y.Z close the [Unreleased] changelog section as X.Y.Z and write X.Y.Z to VERSION; commits nothing"
	@echo "make release         refuse unless on a clean, full main with a bumped VERSION, its changelog section and passing tests;"
	@echo "                     then package, tag vX.Y.Z, push the tag, publish the release with $(ZIP) in doubleloop-io/downtab"
	@echo "make ship V=X.Y.Z    refuse unless on a clean main equal to origin/main with passing tests and smoke;"
	@echo "                     then make version, commit and push on main, make release"
	@echo
	@echo "Release: 1. add user-facing entries under ## [Unreleased] in CHANGELOG.md while working"
	@echo "         2. make version V=X.Y.Z, commit on main"
	@echo "         3. make smoke (manual, needs Accessibility)"
	@echo "         4. make release (from main)"
	@echo "         or, after 1: make ship V=X.Y.Z (steps 2-4, smoke first)"

icon:
	@scripts/make-icon.sh

setup-signing:
	@scripts/setup-signing.sh $(SIGNING_DIR) $(KEYCHAIN_PASSWORD)

build:
	swift build $(SWIFT_FLAGS)

test: check-core test-versioning lint
	swift test $(SWIFT_FLAGS)

test-versioning:
	@scripts/test-versioning.sh

check-core:
	@scripts/check-core.sh

FORMAT_PATHS := Sources Tests Package.swift

format:
	swift format --in-place --recursive $(FORMAT_PATHS)

# SwiftLint's SourceKit lookup misses the Command Line Tools: point it at the active toolchain.
lint:
	swift format lint --strict --recursive $(FORMAT_PATHS)
	TOOLCHAIN_DIR="$$(cd "$$(dirname "$$(xcrun -f swift)")/../.." && pwd)" swift package plugin --allow-writing-to-package-directory swiftlint --strict --quiet

# Checks VERSION and the build number before the slow release build; stamp-version.sh writes them after it.
bundle:
	@test -f "$(KEYCHAIN)" || { echo "signing missing: run make setup-signing"; exit 1; }
	@bash -c 'source scripts/lib/version.sh && read_version >/dev/null && build_number >/dev/null'
	swift build -c release --product $(EXE) $(SWIFT_FLAGS)
	swift build -c release --product EmergencyRestore $(SWIFT_FLAGS)
	mkdir -p build
	cp "$$(swift build -c release --show-bin-path)/EmergencyRestore" "$(RESTORE)"
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build -c release --show-bin-path)/$(EXE)" "$(APP)/Contents/MacOS/$(EXE)"
	cp App/Info.plist "$(APP)/Contents/Info.plist"
	@scripts/stamp-version.sh "$(APP)/Contents/Info.plist"
	cp App/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	@security unlock-keychain -p $(KEYCHAIN_PASSWORD) "$(KEYCHAIN)"
	$(SIGN) "$(APP)"
	$(SIGN) "$(RESTORE)"
	@codesign --verify "$(APP)" && codesign -d -r- "$(APP)" 2>&1 | grep designated

# Quit first: `open` would reactivate a still-exiting instance instead of launching the new build.
run: stop bundle
	@# Launch through LaunchServices so macOS attributes permissions to the bundle, not to the terminal.
	@open "$(APP)" --args -registerLoginItem NO
	@echo "running: look for the Downtab icon in the menu bar"

stop:
	@if pkill -x $(EXE); then \
		while pgrep -x $(EXE) >/dev/null; do sleep 0.1; done; echo stopped; \
	else echo "not running"; fi

# Prefers the copy `make bundle` left: in an emergency it runs at once, without compiling.
$(RESTORE):
	swift build --product EmergencyRestore $(SWIFT_FLAGS)
	mkdir -p build
	cp "$$(swift build --show-bin-path)/EmergencyRestore" "$(RESTORE)"

restore: $(RESTORE)
	@"$(RESTORE)"

restore-status: $(RESTORE)
	@"$(RESTORE)" --status

# Local only: posting synthetic events needs the Accessibility permission for the terminal.
smoke: stop bundle
	@scripts/smoke.sh "$(APP)"

version:
	@scripts/bump-version.sh "$(V)"

package: bundle
	@scripts/package.sh "$(APP)" "$(RESTORE)" "$(ZIP)"

ship:
	@scripts/ship.sh "$(V)"

release:
	@scripts/release-check.sh
	@$(MAKE) --no-print-directory package
	@scripts/release-publish.sh "$(ZIP)"

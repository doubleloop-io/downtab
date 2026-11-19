# Developer commands. CI only runs `build` and `test`: signing material never leaves this Mac.
.DEFAULT_GOAL := help
.PHONY: help setup-signing build test check-core test-versioning lint format icon bundle notarize-check run stop smoke \
	restore restore-status version release ship

EXE := Downtab
APP := build/$(EXE).app
RESTORE_EXE := RestoreCommandTab
RESTORE := build/$(RESTORE_EXE)
DMG := build/$(EXE).dmg
APPCAST := build/appcast.xml
# Signing material lives in the main checkout, shared by its worktrees: one certificate, one Accessibility grant.
MAIN_CHECKOUT := $(shell common=$$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
	&& dirname "$$common" || pwd)
SIGNING_DIR := $(MAIN_CHECKOUT)/.signing
KEYCHAIN := $(SIGNING_DIR)/downtab.keychain-db
KEYCHAIN_PASSWORD := downtab
# Every build signs with Developer ID when the login keychain holds it, so `make run` and the installed release share
# one Accessibility grant: TCC keeps one requirement per bundle id. Without it, the self-signed identity, so
# contributors need no Apple account. Both use the hardened runtime: smoke runs under the release's conditions.
DEVELOPER_ID := $(shell bash -c '. scripts/lib/version.sh && echo "$$DEVELOPER_ID"')
HAS_DEVELOPER_ID := $(shell security find-identity -v -p codesigning 2>/dev/null | grep -qF '"$(DEVELOPER_ID)"' && echo yes)
SIGN_WITH ?= $(if $(HAS_DEVELOPER_ID),developer-id,self-signed)
ifeq ($(SIGN_WITH),developer-id)
SIGN = codesign --force --options runtime --timestamp -s "$(DEVELOPER_ID)"
SIGN_APP = $(SIGN)
else
SIGN = codesign --force --options runtime --timestamp --keychain "$(KEYCHAIN)" \
	-s "$$(openssl x509 -in $(SIGNING_DIR)/cert.crt -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)"
# Library validation refuses Sparkle.framework when the certificate has no Team ID, as the self-signed one has none.
SIGN_APP = $(SIGN) --entitlements App/SelfSigned.entitlements
endif
SPARKLE := $(APP)/Contents/Frameworks/Sparkle.framework
# Inside the bundle so it updates with the app and is always where the app is.
BUNDLED_RESTORE := $(APP)/Contents/MacOS/$(RESTORE_EXE)

# Workaround: with Swift 6.4's default build system, any `swift build` before `swift test` drops the
# Swift Testing macro plugin path ("plugin for module 'TestingMacros' not found"). Passing it explicitly
# on every build and test keeps the build configuration identical across commands.
TESTING_PLUGINS = $(shell dirname "$$(xcrun -f swift)")/../lib/swift/host/plugins/testing
SWIFT_FLAGS = -Xswiftc -plugin-path -Xswiftc "$(TESTING_PLUGINS)"

help:
	@echo "make setup-signing   once per clone: create the self-signed certificate in a dedicated keychain"
	@echo "make build           debug build of the app and of Restore ⌘Tab"
	@echo "make test            check the core boundary and lint, then run the tests"
	@echo "make check-core      fail if the Switcher core imports anything but Foundation or loads private APIs"
	@echo "make lint            swift-format check (.swift-format) and SwiftLint (.swiftlint.yml); any violation fails"
	@echo "make format          rewrite sources with swift-format"
	@echo "make icon            render App/Icon/*.svg into App/AppIcon.icns (needs rsvg-convert)"
	@echo "make bundle          release build, assemble and sign $(APP) with Restore ⌘Tab inside, copied to $(RESTORE)"
	@echo "                     (with $(DEVELOPER_ID) when the keychain holds it, else self-signed;"
	@echo "                     SIGN_WITH=developer-id or SIGN_WITH=self-signed forces one)"
	@echo "make notarize-check  bundle with Developer ID, build $(DMG), sign, notarize, staple and verify it,"
	@echo "                     then sign it for Sparkle into $(APPCAST); tags and publishes nothing."
	@echo "                     make release runs the same steps"
	@echo "make run             bundle, then launch the app (quitting a running instance first)"
	@echo "make stop            quit the running app"
	@echo "make restore         Restore ⌘Tab: turn native ⌘Tab and ⌘\` back on, after a forced kill or a crash"
	@echo "make restore-status  show whether native ⌘Tab and ⌘\` are on, changing nothing"
	@echo "make smoke           bundle, launch, post ⌥/⌥Tab/⌥⇧Tab/⌥\`/⌥⇧\`/Esc, fail on a crash; must pass before closing an issue that touches the app"
	@echo "make version V=X.Y.Z close the [Unreleased] changelog section as X.Y.Z and write X.Y.Z to VERSION; commits nothing"
	@echo "make release         refuse unless on a clean, full main with a bumped VERSION, its changelog section and passing tests;"
	@echo "                     then notarize-check, tag vX.Y.Z, push the tag, publish the release with $(DMG)"
	@echo "                     and $(APPCAST) in doubleloop-io/downtab, point the Homebrew cask in doubleloop-io/homebrew-tap at it"
	@echo "make ship V=X.Y.Z    refuse unless on a clean main equal to origin/main with passing tests, smoke and notarize-check;"
	@echo "                     then make version, commit and push on main, make release"
	@echo
	@echo "Release: 1. add user-facing entries under ## [Unreleased] in CHANGELOG.md while working"
	@echo "         2. make version V=X.Y.Z, commit on main"
	@echo "         3. make smoke (manual, needs Accessibility)"
	@echo "         4. make release (from main)"
	@echo "         or, after 1: make ship V=X.Y.Z (steps 2-4, smoke and notarize-check first)"

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
	@test "$(SIGN_WITH)" = developer-id || test -f "$(KEYCHAIN)" || { echo "signing missing: run make setup-signing"; exit 1; }
	@bash -c 'source scripts/lib/version.sh && read_version >/dev/null && build_number >/dev/null'
	swift build -c release --product $(EXE) $(SWIFT_FLAGS)
	swift build -c release --product $(RESTORE_EXE) $(SWIFT_FLAGS)
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources" "$(APP)/Contents/Frameworks"
	cp "$$(swift build -c release --show-bin-path)/$(EXE)" "$(APP)/Contents/MacOS/$(EXE)"
	cp "$$(swift build -c release --show-bin-path)/$(RESTORE_EXE)" "$(BUNDLED_RESTORE)"
	ditto "$$(swift build -c release --show-bin-path)/Sparkle.framework" "$(SPARKLE)"
	@# Downtab is not sandboxed: Sparkle needs no XPC services, and dropping them leaves less to sign.
	rm -rf "$(SPARKLE)/Versions/B/XPCServices" "$(SPARKLE)/XPCServices"
	cp App/Info.plist "$(APP)/Contents/Info.plist"
	@scripts/stamp-version.sh "$(APP)/Contents/Info.plist"
	cp App/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	@test "$(SIGN_WITH)" = developer-id || security unlock-keychain -p $(KEYCHAIN_PASSWORD) "$(KEYCHAIN)"
	@# Inside out, never --deep: each nested executable and bundle is signed before what contains it.
	$(SIGN) "$(SPARKLE)/Versions/B/Autoupdate"
	$(SIGN) "$(SPARKLE)/Versions/B/Updater.app"
	$(SIGN) "$(SPARKLE)"
	$(SIGN) "$(BUNDLED_RESTORE)"
	$(SIGN_APP) "$(APP)"
	cp "$(BUNDLED_RESTORE)" "$(RESTORE)"
	@codesign --verify "$(APP)" && codesign -d -r- "$(APP)" 2>&1 | grep designated

# Quit first: `open` would reactivate a still-exiting instance instead of launching the new build.
run: stop bundle
	@# Launch through LaunchServices so macOS attributes permissions to the bundle, not to the terminal.
	@open "$(APP)" --args -registerLoginItem NO -SUEnableAutomaticChecks NO
	@echo "running: look for the Downtab icon in the menu bar"

stop:
	@if pkill -x $(EXE); then \
		while pgrep -x $(EXE) >/dev/null; do sleep 0.1; done; echo stopped; \
	else echo "not running"; fi

# Prefers the copy `make bundle` left: when ⌘Tab is broken it runs at once, without compiling.
$(RESTORE):
	swift build --product $(RESTORE_EXE) $(SWIFT_FLAGS)
	mkdir -p build
	cp "$$(swift build --show-bin-path)/$(RESTORE_EXE)" "$(RESTORE)"

restore: $(RESTORE)
	@"$(RESTORE)"

restore-status: $(RESTORE)
	@"$(RESTORE)" --status

# Local only: posting synthetic events needs the Accessibility permission for the terminal.
smoke: stop bundle
	@scripts/smoke.sh "$(APP)"

version:
	@scripts/bump-version.sh "$(V)"

notarize-check:
	@scripts/release-preflight.sh
	@rm -f "$(APPCAST)"
	@$(MAKE) --no-print-directory bundle SIGN_WITH=developer-id
	@scripts/notarize.sh "$(APP)" "$(DMG)"
	@scripts/appcast.sh "$(APP)" "$(DMG)" "$(APPCAST)"

ship:
	@scripts/ship.sh "$(V)"

release:
	@scripts/release-check.sh
	@$(MAKE) --no-print-directory notarize-check
	@scripts/release-publish.sh "$(DMG)" "$(APPCAST)"

# GitHub Sessions — build Release .app and produce a distributable .dmg
#
# Usage:
#   make              # build Release app + DMG
#   make dmg          # same as default
#   make build        # Release .app only
#   make clean        # remove build artifacts
#
# Optional signing (Developer ID):
#   make dmg CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

SCHEME          := GitHubSessions
APP_NAME        := GitHubSessions
PROJECT         := GitHubSessions.xcodeproj
CONFIG          := Release
DERIVED_DATA    := build/DerivedData
APP_PATH        := $(DERIVED_DATA)/Build/Products/$(CONFIG)/$(APP_NAME).app
STAGE_DIR       := build/dmg-stage
DIST_DIR        := dist
VOLUME_NAME     := GitHub Sessions

XCODEGEN        ?= xcodegen
XCODEBUILD      ?= xcodebuild

.DEFAULT_GOAL := dmg

.PHONY: dmg build generate clean sign

dmg: build
	@VERSION=$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '$(APP_PATH)/Contents/Info.plist'); \
	DMG="$(DIST_DIR)/$(APP_NAME)-$$VERSION.dmg"; \
	mkdir -p "$(DIST_DIR)"; \
	rm -rf "$(STAGE_DIR)"; \
	mkdir -p "$(STAGE_DIR)"; \
	echo "Staging $(APP_NAME).app..."; \
	ditto "$(APP_PATH)" "$(STAGE_DIR)/$(APP_NAME).app"; \
	if [[ -n "$(CODESIGN_IDENTITY)" ]]; then \
		echo "Signing with $(CODESIGN_IDENTITY)..."; \
		codesign --force --deep --options runtime --timestamp \
			--sign "$(CODESIGN_IDENTITY)" "$(STAGE_DIR)/$(APP_NAME).app"; \
		codesign --verify --deep --strict --verbose=2 "$(STAGE_DIR)/$(APP_NAME).app"; \
	fi; \
	ln -sf /Applications "$(STAGE_DIR)/Applications"; \
	echo "Creating $$DMG..."; \
	rm -f "$$DMG"; \
	hdiutil create -volname "$(VOLUME_NAME)" -srcfolder "$(STAGE_DIR)" -ov -format UDZO "$$DMG"; \
	rm -rf "$(STAGE_DIR)"; \
	echo "DMG ready: $$DMG ($$(du -sh "$$DMG" | cut -f1))"

build: generate $(APP_PATH)
	@echo "App ready: $(APP_PATH)"

generate: $(PROJECT)/project.pbxproj

$(PROJECT)/project.pbxproj: project.yml
	@command -v $(XCODEGEN) >/dev/null 2>&1 || { echo "xcodegen not found; install with: brew install xcodegen" >&2; exit 1; }
	$(XCODEGEN) generate

$(APP_PATH): $(PROJECT)/project.pbxproj
	@mkdir -p "$(DERIVED_DATA)"
	$(XCODEBUILD) \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIG)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		-destination 'platform=macOS' \
		build
	@test -d "$(APP_PATH)" || { echo "Build succeeded but app not found at $(APP_PATH)" >&2; exit 1; }

sign: build
	@if [[ -z "$${CODESIGN_IDENTITY:-}" ]]; then \
		echo 'Set CODESIGN_IDENTITY to sign the app, e.g. make sign CODESIGN_IDENTITY="Developer ID Application: …"' >&2; \
		exit 1; \
	fi
	@codesign --force --deep --options runtime --timestamp \
		--sign "$(CODESIGN_IDENTITY)" "$(APP_PATH)"
	@codesign --verify --deep --strict --verbose=2 "$(APP_PATH)"

clean:
	@rm -rf build dist
	@echo "Removed build/ and dist/"
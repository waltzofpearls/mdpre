.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

APP := MDPre
APP_NAME := Markdown Preview
BUILD := ./build
BIN := $(BUILD)/bin
TMP := $(BUILD)/tmp

.PHONY: all
all: build

MARKETING_VERSION=$(shell git describe --tags --abbrev=0 >/dev/null 2>&1 && (git describe --tags --abbrev=0 | sed 's/v//') || echo "1.0.0")
BUILD_VERSION=$(shell git rev-list HEAD --count)
BUILD_HASH=$(shell git rev-parse --short HEAD)

.PHONY: build
build: ## Build the app
	-rm -rf "$(BIN)/$(APP_NAME).app"
	-rm -f $(BIN)/Markdown-Preview.dmg
	make app
	make sign
	make dmg
	make notarize

.PHONY: app
app:
	-rm -rf $(TMP)
	mkdir -p $(TMP)
	xcodebuild -project ./$(APP).xcodeproj/ \
		-scheme $(APP) \
		-configuration Release \
		MARKETING_VERSION="$(MARKETING_VERSION)" \
		CURRENT_PROJECT_VERSION="$(BUILD_VERSION)" \
		ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
		-sdk macosx MACOSX_DEPLOYMENT_TARGET=15.7 \
		-derivedDataPath $(TMP) \
		clean build
	mkdir -p $(BIN)
	mv "$(TMP)/Build/Products/Release/$(APP_NAME).app" $(BIN)/

.PHONY: sign
sign:
	@if [[ "$(APPLE_PASSWORD)" != "" ]]; then \
		AC_PASSWORD=$(APPLE_PASSWORD) gon -log-level=info ./build/gon-sign.json ; \
	fi

.PHONY: dmg
dmg:
	mkdir -p $(BIN)/macos
	mv "$(BIN)/$(APP_NAME).app" $(BIN)/macos/
	create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "$(BIN)/macos/$(APP_NAME).app/Contents/Resources/AppIcon.icns" \
		--background "$(BUILD)/dmg_background.png" \
		--window-pos 210 120 \
		--window-size 665 525 \
		--icon-size 100 \
		--icon "$(APP_NAME).app" 160 355 \
		--app-drop-link 490 355 \
		--hide-extension "$(APP_NAME).app" \
		--no-internet-enable \
		"$(BIN)/Markdown-Preview.dmg" \
		"$(BIN)/macos" \
		|| test $$? -eq 2
	mv "$(BIN)/macos/$(APP_NAME).app" $(BIN)/
	rm -rf $(BIN)/macos

.PHONY: notarize
notarize:
	@if [[ "$(APPLE_PASSWORD)" != "" ]]; then \
		AC_PASSWORD=$(APPLE_PASSWORD) gon -log-level=info ./build/gon-notarize.json ; \
	fi

.PHONY: sign-verify
sign-verify: ## Verify code signature
	codesign --verify --deep --strict --verbose=2 "$(BIN)/$(APP_NAME).app"
	codesign --verify --verbose=1 "$(BIN)/$(APP_NAME).app/Contents/MacOS/mdp"
	spctl --assess --type exec --verbose "$(BIN)/$(APP_NAME).app"

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(BIN) $(TMP)

.PHONY: release-store
release-store: ## App Store release (not yet implemented)
	@echo "App Store release not yet implemented."
	@echo "Requires: Apple Distribution certificate, Transporter or xcrun altool."
	@exit 1

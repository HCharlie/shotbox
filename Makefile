SCHEME        := CleanShotAlt
PROJECT       := CleanShotAlt.xcodeproj
APP_NAME      := CleanShotAlt.app
BUILD_DIR     := build
INSTALL_PATH  := /Applications/$(APP_NAME)
CONFIGURATION ?= Release

# ── Phony targets ─────────────────────────────────────────────────────────────
.PHONY: all setup generate build install uninstall modules clean open help

all: build

# ── Setup ─────────────────────────────────────────────────────────────────────
## Install required tools (Homebrew + xcodegen)
setup:
	@echo "→ Checking Homebrew..."
	@command -v brew >/dev/null 2>&1 || \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@echo "→ Checking xcodegen..."
	@command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
	@echo "→ Checking Xcode command-line tools..."
	@xcode-select -p >/dev/null 2>&1 || xcode-select --install
	@echo "✓ Setup complete"

# ── Generate ──────────────────────────────────────────────────────────────────
## Regenerate .xcodeproj from project.yml
generate:
	@echo "→ Generating Xcode project..."
	xcodegen generate
	@echo "✓ $(PROJECT) regenerated"

# ── Build SPM modules only (no Xcode needed) ─────────────────────────────────
## Build all 6 local SPM packages (works without Xcode.app)
modules:
	@echo "→ Building SPM modules..."
	@for pkg in SharedModels HistoryStore DesktopManager OCRService CaptureEngine AnnotationEditor; do \
		echo "  • $$pkg"; \
		(cd Modules/$$pkg && swift build) || exit 1; \
	done
	@echo "✓ All modules built"

# ── Build app ─────────────────────────────────────────────────────────────────
## Build the full app target (requires Xcode.app)
build: generate
	@echo "→ Building $(SCHEME) [$(CONFIGURATION)]..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'generic/platform=macOS' \
		build | xcpretty 2>/dev/null || cat
	@echo "✓ Build complete"

# ── Install ───────────────────────────────────────────────────────────────────
## Copy built app to /Applications (builds first if needed)
install: build
	@echo "→ Installing to $(INSTALL_PATH)..."
	@APP=$$(find $(BUILD_DIR) -name "$(APP_NAME)" -type d | head -1); \
	if [ -z "$$APP" ]; then echo "✗ $(APP_NAME) not found in $(BUILD_DIR). Run 'make build' first." && exit 1; fi; \
	if [ -d "$(INSTALL_PATH)" ]; then rm -rf "$(INSTALL_PATH)"; fi; \
	cp -R "$$APP" "$(INSTALL_PATH)"
	@echo "✓ Installed to $(INSTALL_PATH)"
	@echo "  Open from Spotlight or: open $(INSTALL_PATH)"

# ── Uninstall ─────────────────────────────────────────────────────────────────
## Remove app from /Applications
uninstall:
	@if [ -d "$(INSTALL_PATH)" ]; then \
		rm -rf "$(INSTALL_PATH)"; \
		echo "✓ Removed $(INSTALL_PATH)"; \
	else \
		echo "  $(APP_NAME) is not installed"; \
	fi

# ── Open in Xcode ─────────────────────────────────────────────────────────────
## Open the project in Xcode
open: generate
	open $(PROJECT)

# ── Clean ─────────────────────────────────────────────────────────────────────
## Remove build artifacts
clean:
	@echo "→ Cleaning..."
	rm -rf $(BUILD_DIR)
	@for pkg in SharedModels HistoryStore DesktopManager OCRService CaptureEngine AnnotationEditor; do \
		rm -rf Modules/$$pkg/.build; \
	done
	@echo "✓ Clean complete"

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Shotbox — macOS Screenshot App"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  setup      Install Homebrew, xcodegen, and Xcode CLI tools"
	@echo "  generate   Regenerate .xcodeproj from project.yml"
	@echo "  modules    Build all 6 SPM modules (no Xcode.app needed)"
	@echo "  build      Build the full app  [CONFIGURATION=Debug|Release]"
	@echo "  install    Build + copy to /Applications"
	@echo "  uninstall  Remove from /Applications"
	@echo "  open       Open in Xcode"
	@echo "  clean      Remove build artifacts"
	@echo ""
	@echo "  Requires Xcode.app for 'build', 'install', 'open'."
	@echo "  'modules' works with Command Line Tools only."
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# RBX Rewards — Developer Makefile
#
# Usage:
#   make run         → Generate secrets + run on connected device
#   make ios         → Generate secrets + run on iOS simulator
#   make test        → Generate test secrets + run all E2E tests
#   make test-05     → Run only suite 05 (profile & settings)
#   make build       → Generate secrets + build release APK
#   make build-ios   → Generate secrets + build iOS IPA
#   make secrets     → Regenerate app_secrets.dart from env.json
#   make setup       → First-time dev setup (copy env template)
#   make clean       → flutter clean + remove generated secrets
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run ios test test-% build build-ios secrets setup clean

# Detect connected Android device automatically
ANDROID_DEVICE := $(shell flutter devices 2>/dev/null | grep android-arm | awk -F'•' '{print $$2}' | tr -d ' ' | head -1)

## ── Generate secrets ─────────────────────────────────────────────────────────
secrets:
	@echo "▶  Generating app_secrets.dart from env.json..."
	@dart run tool/generate_secrets.dart

## ── Run on Android ───────────────────────────────────────────────────────────
run: secrets
	@echo "▶  Running on Android ($(ANDROID_DEVICE))..."
	flutter run $(if $(ANDROID_DEVICE),-d $(ANDROID_DEVICE),)

## ── Run on iOS simulator ─────────────────────────────────────────────────────
ios: secrets
	@echo "▶  Running on iOS simulator..."
	flutter run -d "iPhone 15"

## ── E2E tests — all suites ───────────────────────────────────────────────────
test: _test-secrets
	@echo "▶  Running all E2E suites on $(ANDROID_DEVICE)..."
	flutter test integration_test/ -d $(ANDROID_DEVICE) -v

## ── E2E tests — single suite (make test-05) ──────────────────────────────────
test-%: _test-secrets
	@SUITE=$*; \
	FILE=$$(ls integration_test/$${SUITE}_*.dart 2>/dev/null | head -1); \
	if [ -z "$$FILE" ]; then echo "❌ No test file matching integration_test/$${SUITE}_*.dart"; exit 1; fi; \
	echo "▶  Running $$FILE on $(ANDROID_DEVICE)..."; \
	flutter test $$FILE -d $(ANDROID_DEVICE) -v

## ── Build release APK ────────────────────────────────────────────────────────
build: secrets
	@echo "▶  Building release APK..."
	flutter build apk --release --obfuscate --split-debug-info=build/debug-info
	@echo ""
	@echo "✅ APK: build/app/outputs/flutter-apk/app-release.apk"

## ── Build iOS IPA ────────────────────────────────────────────────────────────
build-ios: secrets
	@echo "▶  Building iOS IPA..."
	flutter build ipa --release --obfuscate --split-debug-info=build/debug-info
	@echo ""
	@echo "✅ IPA: build/ios/ipa/"

## ── First-time setup ─────────────────────────────────────────────────────────
setup:
	@if [ ! -f env.json ]; then \
		cp env.example.json env.json; \
		echo "✅ Created env.json — fill in your real API keys."; \
	else \
		echo "✓  env.json already exists."; \
	fi
	@if [ ! -f env.test.json ]; then \
		cp env.example.json env.test.json; \
		echo "✅ Created env.test.json — set INTEGRATION_TEST to true inside it."; \
	else \
		echo "✓  env.test.json already exists."; \
	fi
	flutter pub get
	dart run tool/generate_secrets.dart
	@echo ""
	@echo "✅ Setup complete! Run: make run"

## ── Clean ────────────────────────────────────────────────────────────────────
clean:
	flutter clean
	@rm -f lib/core/config/app_secrets.dart
	@echo "✅ Cleaned build artifacts and generated secrets."

## ── Internal: switch env to test mode ───────────────────────────────────────
_test-secrets:
	@echo "▶  Switching to test environment (INTEGRATION_TEST=true)..."
	@dart run tool/generate_secrets.dart --env=env.test.json

# Uses FVM by default so everyone runs the pinned Flutter version.
# Without FVM:  make test FLUTTER=flutter DART=dart
FLUTTER ?= fvm flutter
DART ?= fvm dart
DART_FILES = $$(git ls-files '*.dart')

.PHONY: help setup platforms gen format format-check analyze check-colors test coverage check \
        run-dev run-staging run-prod build-apk-prod build-appbundle-prod build-ipa-prod clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

setup: ## Install deps, generate l10n, create local config files from templates
	$(FLUTTER) pub get
	$(FLUTTER) gen-l10n
	@for f in dev staging prod; do [ -f config/$$f.json ] || cp config/$$f.example.json config/$$f.json; done

platforms: ## One-time: generate android/ and ios/ (commit them afterwards)
	$(FLUTTER) create --org ng.gov.vitalreg --project-name vital_reg_mobile --platforms android,ios .
	rm -f lib/main.dart test/widget_test.dart

gen: ## Regenerate localizations
	$(FLUTTER) gen-l10n

format: ## Format tracked Dart files
	$(DART) format $(DART_FILES)

format-check: ## Fail if formatting is off (same as CI)
	$(DART) format --output=none --set-exit-if-changed $(DART_FILES)

analyze: ## Static analysis; infos fail the build (same as CI)
	$(FLUTTER) analyze --fatal-infos

check-colors: ## Fail if colour literals appear outside lib/design_system
	@if grep -rn --include='*.dart' 'Color(0x' lib | grep -v '^lib/design_system/'; then \
		echo 'Colour literals must live in lib/design_system/'; exit 1; \
	fi

test: ## Run all tests
	$(FLUTTER) test

coverage: ## Run tests with coverage (coverage/lcov.info)
	$(FLUTTER) test --coverage

check: format-check analyze check-colors test ## Everything CI runs

run-dev: ## Run the dev flavor
	$(FLUTTER) run -t lib/main_dev.dart --dart-define-from-file=config/dev.json

run-staging: ## Run the staging flavor
	$(FLUTTER) run -t lib/main_staging.dart --dart-define-from-file=config/staging.json

run-prod: ## Run the prod flavor in release mode
	$(FLUTTER) run --release -t lib/main_prod.dart --dart-define-from-file=config/prod.json

# Release builds are always obfuscated. Keep build/symbols/ (upload it to
# Sentry) so stack traces can be de-obfuscated.
build-apk-prod: ## Release APK (obfuscated)
	$(FLUTTER) build apk --release -t lib/main_prod.dart --dart-define-from-file=config/prod.json \
		--obfuscate --split-debug-info=build/symbols/android

build-appbundle-prod: ## Release App Bundle for Play Store (obfuscated)
	$(FLUTTER) build appbundle --release -t lib/main_prod.dart --dart-define-from-file=config/prod.json \
		--obfuscate --split-debug-info=build/symbols/android

build-ipa-prod: ## Release IPA (obfuscated)
	$(FLUTTER) build ipa --release -t lib/main_prod.dart --dart-define-from-file=config/prod.json \
		--obfuscate --split-debug-info=build/symbols/ios

clean: ## Remove build outputs
	$(FLUTTER) clean

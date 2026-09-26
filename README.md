# Vital Reg Mobile

Flutter app for vital registration (births, deaths, approvals, reports).

## Prerequisites

- [FVM](https://fvm.app) — the Flutter version is pinned in `.fvmrc` and `pubspec.yaml`
- `make` (Windows: `choco install make`, or run the commands from the `Makefile` by hand)
- Android Studio / Xcode for device builds

## First run

```bash
fvm install            # installs the pinned Flutter version
make setup             # pub get, gen-l10n, creates config/*.json from the templates
make platforms         # one time only: generates android/ and ios/; commit them
# edit config/dev.json → set API_BASE_URL
make run-dev           # or use the "dev" launch config in VS Code
```

## Everyday commands

| Command | What it does |
|---|---|
| `make check` | Everything CI runs: format check, analyze (infos fail), colour guard, tests |
| `make test` / `make coverage` | Unit, bloc and widget tests |
| `make format` | Formats tracked Dart files |
| `make gen` | Regenerates localizations after editing `lib/l10n/arb/*.arb` |
| `make run-dev` / `run-staging` / `run-prod` | Runs a flavor |
| `make build-appbundle-prod` | Obfuscated release bundle (keep `build/symbols/`) |
| `make help` | Lists every target |

## Configuration

Each flavor reads `config/<flavor>.json` through `--dart-define-from-file`.
Only `config/*.example.json` is committed; your real `config/*.json` files are gitignored.

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Backend base URL (`https://` required outside dev) |
| `SESSION_TIMEOUT_MINUTES` | Inactivity sign-out |
| `SENTRY_DSN` | Crash reporting; empty = log locally |
| `FEATURES` | Comma-separated enabled modules. **Anything unfinished stays off in prod.** |

**No secrets go in config.** Everything compiled into the app can be extracted.
Payment keys, signing keys and service credentials belong on the backend.

## Layout

```
lib/
  main_{dev,staging,prod}.dart   flavor entry points → bootstrap.dart
  app/                           composition root, router, app shell pages
  core/                          config, network, session, errors, observability, flags
  design_system/                 tokens, theme, shared widgets (only place for colours)
  features/<feature>/            domain / data / presentation
  l10n/                          ARB files + failure → message mapping
test/                            mirrors lib/
```

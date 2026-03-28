# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] Amsterdam - 2026-03-28

### Added

- Structured per-pass reporting carried through `BuildResult`, including pass
  metrics and failure records that later reporters can reuse.
- Plain-text build reporting for local CLI runs.
- GitHub Actions summary reporting for CI environments.
- Resistance coverage based on compiled-artifact `strings` inspection for
  rename and string-encrypt fixtures.
- Stronger rename and string-encrypt regression coverage, including callable
  alias and runtime smoke scenarios.

### Changed

- Promoted the current reporting and correctness-hardening work to the `0.2.0`
  release baseline.
- Moved build presentation concerns out of `BuildCommand` into dedicated
  reporters.
- Clarified and enforced the nested `refractor.passes` configuration shape used
  by `refractor init` and config loading.

### Removed

- **Dead code pass** removed entirely (don't worry, it will return eventually ;) )

## [0.1.0] - 2026-03-01

Initial release.

### Features

- **Rename pass** — rewrites class, method, and field names to short obfuscated identifiers (`_$0`, `_$1`, ...). Optionally preserves `main` and honours `@pragma` annotations.
- **String encryption pass** — replaces string literals with XOR-encoded byte arrays and an injected runtime decoder. Configurable key and exclude patterns.
- **Dead code pass** — inserts unreachable `if (false)` branches to hinder static analysis. Configurable insertion count per procedure.
- **CLI** — `refractor build`, `refractor inspect`, and `refractor init` commands.
- **Build targets** — `exe`, `aot`, `jit`, and `kernel` output formats.
- **Configuration** — `refractor.yaml` with strict validation, `glob`-based library exclusions, and per-pass options.
- **Symbol map** — JSON mapping of obfuscated names back to originals for debugging.
- **Inspect command** — tree view of `.dill` file contents (powered by `kernel_model` package).
- **Test suite** — coverage for CLI commands, config loading/parsing, engine pipeline, and all three obfuscation passes.

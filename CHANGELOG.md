# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2026-04-10

### Added

- Refractor-owned rename keep annotations through the new standalone
  `refractor_annotation` package with the public API `@Refractor.keep()`.
- Rename-policy and regression coverage for annotation-driven preservation,
  including class-level propagation, constructor coverage, and package smoke
  tests for the new annotations package.
- Example app usage of `@Refractor.keep()` to demonstrate preserving selected
  rename-sensitive surfaces without relying on compiler pragmas.

### Changed

- Rename policy now recognizes explicit Refractor keep annotations instead of
  treating generic `@pragma` metadata as a rename keep signal.
- Keep-annotation detection now accepts the annotation package's public export
  URI and defining `src` URI so compiled kernels resolve correctly.
- Example application wiring now depends on `refractor_annotation` directly for
  source-level keep markers.

## [0.2.1] - 2026-04-02

### Added

- String-encrypt coverage for literal segments inside kernel
  `StringConcatenation` nodes, including mixed-expression interpolation cases.
- UTF-8 and target-matrix verification for `string_encrypt`, covering `exe`,
  `jit`, and `aot` rename-plus-string-encrypt workflows.
- Structural coverage for the injected string-encrypt decode helper and its
  `@pragma('vm:never-inline')` hardening.

### Changed

- Reworked `string_encrypt` around the current staged pass architecture and
  strengthened its runtime codec to use a UTF-8-safe reversed multi-byte XOR
  pipeline.
- Moved string-encrypt helper injection into the transformation stage so
  selection stays source-focused and all pass mutation stays in the transformer.
- Unified string-encrypt literal exclusion behind policy instead of keeping a
  selector-local exclusion path.
- Normalized JIT and AOT snapshot output handling for `.dill`-based builds.
- Generic artifact output now removes stale `build_artifacts.json` files when a
  successful build produces no artifacts.

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

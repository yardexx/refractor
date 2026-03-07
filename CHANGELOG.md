# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- **Dead code pass** — removed entirely. The Dart VM's CFG optimizer (ConstantPropagation + ControlFlowOptimizations) eliminates all inserted dead branches regardless of predicate complexity, because the branch bodies have no observable side effects. The pass provided zero obfuscation value in compiled output. See `docs/optimization-resistance.md` for full analysis. **Breaking:** existing `refractor.yaml` files with a `dead_code:` key will now throw `ConfigException`.

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

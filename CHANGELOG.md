# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-01
### Added
- Kernel model package used by `inspect` command for `.dill` inspection tree output.
- Comprehensive test coverage for CLI commands, config loading/parsing, and engine behaviors.
- `glob`-based exclude matching for library URI/path filtering.

### Changed
- `refractor.yaml` loading is now strict: missing, empty, or invalid config fails fast.
- Obfuscation scope is fixed to the current project (current folder + current `pubspec.yaml` package name).
- `ConfigManager` is now strict and focused on file discovery + parsing only.
- `RefractorConfig.fromYaml` now throws on empty, malformed, or non-map YAML roots.
- `rename` config has been simplified; only `preserve_main` remains.
- `build` command defaults target to `exe` and ensures output directories exist.

### Removed
- Implicit config fallbacks and silent defaulting behavior when config is invalid.
- Rename pass hardcoded built-in exclusion names.
- Rename config keys: `exclude_names`, `exclude_patterns`, and `exclude_annotations`.

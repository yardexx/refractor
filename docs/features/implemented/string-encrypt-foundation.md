# String-Encrypt Foundation

**Status:** implemented
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** current codebase baseline
**Related:** [../development/05-resistance-tests.md](../development/05-resistance-tests.md), [../future/string-encrypt-improvements.md](../future/string-encrypt-improvements.md)

## Goal

Document the string-encrypt capabilities that are already present in the
codebase and can be treated as current baseline behavior.

## Implemented Capabilities

- replacement of eligible `StringLiteral` nodes with decode-helper calls
- injected helper procedure in the first obfuscated user library
- per-string random keys rather than one shared key per build
- skipping of const contexts and annotation paths in the current transformer
- exclusion-pattern support for strings that must remain plaintext

## Code Evidence

- pass orchestration and helper injection:
  [string_encrypt_pass.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/engine/passes/string_encrypt/string_encrypt_pass.dart)
- AST transformation behavior:
  [string_encrypt_transformer.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/engine/passes/string_encrypt/string_encrypt_transformer.dart)

## Verification Signals

- behavior is covered in
  [string_encrypt_pass_test.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/test/engine/passes/string_encrypt_pass_test.dart)
- tests explicitly cover helper injection, const skipping, annotation skipping,
  exclude patterns, and per-string keys

## Not Covered By This Doc

These remain later string-encrypt features, not current baseline:

- `StringInterpolation` handling
- decode-helper `vm:never-inline`
- multi-layer encoding
- string array indirection
- deduplication policy

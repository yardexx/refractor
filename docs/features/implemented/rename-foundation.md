# Rename Foundation

**Status:** implemented
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** current codebase baseline
**Related:** [../../architecture/rename-pass.md](../../architecture/rename-pass.md), [../future/rename-improvements.md](../future/rename-improvements.md)

## Goal

Document the rename capabilities that are already present in the codebase and
can be treated as current baseline behavior.

## Implemented Capabilities

- renaming of classes, members, local variables, and parameters
- static call-site safety for renamed members
- constructor-related rename safety for invocation and initializer paths
- seeded shuffled name generation
- deterministic seed plumbing from config into rename generation

## Code Evidence

- rename orchestration and strategy selection:
  [rename_pass.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/engine/passes/rename/rename_pass.dart)
- seeded shuffled generator:
  [shuffled_generator.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/engine/passes/rename/name_generator/shuffled_generator.dart)
- rename transformer coverage:
  [rename_transformer.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/engine/passes/rename/rename_transformer.dart)
- config support for seed:
  [rename_pass_config.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/lib/src/config/model/rename_pass_config.dart)

## Verification Signals

- static and constructor rename behavior is covered in
  [rename_pass_test.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/test/engine/passes/rename/rename_pass_test.dart)
- shuffled generator determinism is covered in
  [name_generator_test.dart](/Users/jaroslavnovotny/Development/Secret/dev/refractor/test/engine/passes/rename/name_generator/name_generator_test.dart)

## Not Covered By This Doc

These remain later rename features, not current baseline:

- name overloading
- mapping stability modes
- keep-name annotations
- misleading-name strategies

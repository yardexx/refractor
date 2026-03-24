# Decode Helper `never-inline`

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.1` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [string-encrypt-improvements.md](string-encrypt-improvements.md)

## Goal

Reduce the chance that decode logic is trivially reintroduced at call sites by
marking the injected helper with `@pragma('vm:never-inline')`.

## Scope

Included:

- helper annotation in injected kernel AST
- verification that helper indirection remains visible in tested modes

Not included:

- stronger encoding design by itself
- guarantees for untested compiler/toolchain combinations

## Acceptance Criteria

- injected helper carries the `vm:never-inline` pragma
- tested JIT and AOT artifacts preserve the intended helper indirection

## Test Plan

- unit or structural tests for helper annotation presence
- manual or fixture-based verification in tested compilation modes

## Open Questions

- how much verification do we require before calling this behavior reliable
  across supported SDK versions?

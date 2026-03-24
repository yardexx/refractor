# StringInterpolation Handling

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.1` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [string-encrypt-improvements.md](string-encrypt-improvements.md)

## Goal

Handle `StringInterpolation` nodes so literal segments inside interpolations are
protected without changing expression semantics.

## Scope

Included:

- visit and transform literal parts inside `StringInterpolation`
- preserve expression segments unchanged
- preserve segment ordering exactly

Not included:

- broader encoding redesign
- string-store indirection

## Acceptance Criteria

- literal segments inside interpolation nodes are transformed
- expression segments remain unmodified
- output behavior matches baseline fixtures

## Test Plan

- unit tests for mixed literal and expression interpolations
- Unicode interpolation fixtures
- regression coverage for ordering preservation

## Open Questions

- should empty literal segments be preserved verbatim or normalized away if the
  kernel structure allows it?

## Definition

For every `StringInterpolation`:

- replace each literal segment with a decode invocation
- keep expression segments (`$x`, `${expr}`) unchanged
- preserve original segment ordering exactly

# Multi-Layer Encoding

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.1` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [string-encrypt-improvements.md](string-encrypt-improvements.md)

## Goal

Replace the weakest current string encoding path with a stronger but still
maintainable multi-step encode/decode flow.

## Scope

Included:

- UTF-8 safe encode/decode flow
- per-string keying
- chained transforms such as XOR, reverse, and Base64

Not included:

- array indirection
- alternate heavier cipher families unless separately planned

## Acceptance Criteria

- encoded strings round-trip correctly, including multi-byte text
- per-string keys remain valid and non-zero
- tested artifacts no longer expose the previous trivial single-step path

## Test Plan

- Unicode round-trip fixtures
- per-string key coverage
- JIT/AOT parity checks on representative fixtures

## Open Questions

- is the current planned chain the right balance of resistance and simplicity,
  or should it stay intentionally minimal?

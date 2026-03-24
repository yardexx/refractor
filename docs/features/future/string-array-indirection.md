# String Array Indirection

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** post-`v0.2.1` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [string-encrypt-improvements.md](string-encrypt-improvements.md)

## Goal

Break direct string-to-usage association by moving protected strings into a
per-library store and rewriting usage sites to indexed lookups.

## Scope

Included:

- one store per transformed library
- rewrite of usage sites to index-based lookup
- documented initialization behavior

Not included:

- cross-library global stores
- deduplication policy beyond what is explicitly designed for the store

## Acceptance Criteria

- strings are rewritten to store lookups
- store initialization behavior is explicit and correct
- usage remains functionally equivalent to baseline

## Test Plan

- rewrite coverage for representative string-use sites
- tests for per-library store behavior
- regression checks for initialization semantics

## Open Questions

- should store initialization remain eager, or become lazy if startup cost
  becomes too noticeable?

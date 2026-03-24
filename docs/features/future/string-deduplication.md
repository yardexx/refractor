# String Deduplication

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** post-`v0.2.1` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [string-encrypt-improvements.md](string-encrypt-improvements.md)

## Goal

Offer an explicit policy for trading some per-occurrence variance for smaller
artifacts by deduplicating protected strings within a library.

## Scope

Included:

- boolean configuration surface for deduplication
- library-local deduplication behavior
- size/resistance tradeoff documentation

Not included:

- cross-library deduplication
- making deduplication the default without supporting data

## Acceptance Criteria

- disabled mode keeps per-occurrence independence
- enabled mode deduplicates by plaintext within a library
- functional behavior remains unchanged in both modes

## Test Plan

- duplicate-string fixtures with dedup off and on
- size comparison reporting on benchmark fixtures
- regression coverage for unchanged runtime behavior

## Open Questions

- should deduplication remain opt-in permanently, or become environment- or
  profile-dependent later?

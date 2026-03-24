# String-Encrypt Improvements

**Status:** future
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** string-encrypt feature family across `v0.2.x+`
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [../../architecture/optimization-resistance.md](../../architecture/optimization-resistance.md), [../implemented/string-encrypt-foundation.md](../implemented/string-encrypt-foundation.md), [../development/05-resistance-tests.md](../development/05-resistance-tests.md), [../README.md](../README.md)

## Goal

Keep the string-encrypt pass correct, optimizer-resistant in tested modes, and
operationally understandable without turning this document into one giant spec.

This file is the coordination doc for the string-encrypt feature family. It
should describe:

- what the string-encrypt area is trying to achieve
- what is active now
- what subfeatures already have their own docs
- what remains later work

Detailed implementation plans belong in dedicated child specs.

## Scope

Included:

- near-term priorities for the string-encrypt feature family
- current constraints and safety expectations
- links to dedicated string-encrypt subfeature docs

Not included:

- full implementation detail for every subfeature
- duplicated design notes that already live in child docs
- broad future speculation unrelated to current string handling

## Security Position

These techniques are treated as strongly resilient only under tested compiler
modes where runtime decode calls and non-const data flow survive optimization.

That means:

- claims should stay tied to tested JIT and AOT workflows
- docs should avoid absolute language unless backed by tests
- resistance claims should be validated through correctness and resistance
  fixtures, not only by reasoning

## Current Priorities

### 1. Correctness And Coverage

Near-term work should first preserve correctness:

- handle currently uncovered string expression forms safely
- preserve Unicode correctness
- keep output behavior identical to baseline programs

### 2. Decode-Path Hardening

The current implemented decode path should become less trivial to undo:

- avoid obvious inlining of helper logic
- move beyond the weakest current encoding approach
- keep the design understandable enough to debug and test

### 3. Operational Confidence

String-encrypt work should stay practical to ship:

- resistance checks should be explicit
- performance and size tradeoffs should be documented
- per-feature behavior should have focused test plans

## Current String-Encrypt Gaps

These are the main active concerns for the string-encrypt area:

- interpolation handling is not yet fully covered
- current encoding is still comparatively weak even though per-string keys are
  already in place
- direct string-to-usage association is still preserved in many cases
- operational tradeoffs like deduplication need explicit policy and tests

## Subfeatures With Dedicated Docs

Use these docs instead of expanding this file:

- [string-interpolation-handling.md](string-interpolation-handling.md)
  For interpolation-segment coverage
- [decode-helper-never-inline.md](decode-helper-never-inline.md)
  For helper indirection hardening
- [multi-layer-encoding.md](multi-layer-encoding.md)
  For stronger encode/decode flow
- [string-array-indirection.md](string-array-indirection.md)
  For store-and-index rewrite behavior
- [string-deduplication.md](string-deduplication.md)
  For optional deduplication policy

## Planned String-Encrypt Roadmap

### Near-Term

- interpolation coverage
- decode helper `never-inline`
- multi-layer encoding
- Unicode regression coverage

### Medium-Term

- string array indirection
- explicit deduplication policy and benchmarking

### Later

- stronger alternative cipher approaches if they remain maintainable
- further resistance work only when it stays testable and operationally sane

## Acceptance Criteria

This coordination doc is doing its job when:

- string-encrypt priorities are easy to understand without reading one giant
  design doc
- each substantial subfeature has its own dedicated spec
- roadmap files can link here for family direction and to child docs for
  implementation details

## Test Plan

This file does not define one implementation test plan. Each string-encrypt
subfeature must carry its own concrete test plan.

At the feature-family level, string-encrypt changes should continue to require:

- correctness parity against representative fixtures
- Unicode regression coverage where relevant
- resistance checks for plaintext leakage where relevant

## Open Questions

- which string-hardening steps should become default behavior first?
- what performance budget is acceptable for stronger encoding layers?
- when should deduplication be preferred over stronger per-occurrence variance?
- how far should we push string-encrypt complexity before maintainability drops
  too much?

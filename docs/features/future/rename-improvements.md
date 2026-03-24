# Rename Improvements

**Status:** future
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** rename feature family across `v0.2.x+`
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [../../architecture/rename-pass.md](../../architecture/rename-pass.md), [../implemented/rename-foundation.md](../implemented/rename-foundation.md), [01-name-overloading.md](01-name-overloading.md)

## Goal

Keep the rename pass correct, predictable, and hard enough to reverse without
turning this document into a mega-spec.

This file is the coordination doc for the rename feature family. It should
describe:

- what the rename area is trying to achieve
- what is active now
- what subfeatures already have their own docs
- what remains future work

Detailed implementation plans belong in dedicated child specs.

## Scope

Included:

- rename-pass priorities across near-term releases
- current gaps and constraints
- links to dedicated rename subfeature docs

Not included:

- full implementation detail for every rename subfeature
- duplicated design notes that already live in child docs
- deep future speculation about AI-assisted rename strategies

## Current Priorities

### 1. Correctness And Coverage

Near-term rename work should first preserve correctness:

- cover remaining rename targets safely
- keep dispatch and canonical-name behavior correct
- maintain E2E confidence and regression coverage

### 2. Reproducibility And Operator Trust

Rename output should become easier to reason about operationally:

- deterministic behavior under a clearer project-level seed and mapping policy
- understandable mapping behavior
- stable symbol artifacts for debugging and symbolication

### 3. Hardening After Correctness

Once the current implemented foundation is stable, rename can become harder to
analyze:

- name overloading
- later, misleading-name strategies

## Current Rename Gaps

These are the main active concerns for the rename area:

- complete and trustworthy rename target coverage still matters more than
  adding advanced naming tricks
- mapping stability and seed behavior are not yet fully defined at the project
  level
- keep-name annotation policy is still a future feature

## Subfeatures With Dedicated Docs

Use these docs instead of expanding this file:

- [../future/01-name-overloading.md](../future/01-name-overloading.md)
  For slot reuse across unrelated hierarchies

Additional rename-adjacent work that still needs its own dedicated doc later:

- mapping stability modes
- annotation-based controls

Future rename strategy docs:

- [../future/misleading-name-strategies.md](../future/misleading-name-strategies.md)
  For dictionary-based and AI-assisted misleading rename
- [../future/refractor-annotations.md](../future/refractor-annotations.md)
  For broader annotation-based feature control

## Planned Rename Roadmap

### Near-Term

- finish safe rename coverage and correctness hardening
- settle deterministic name-generation behavior
- keep rename architecture understandable and maintainable

### Medium-Term

- add name overloading if it can be proven safe
- add stable vs rotating mapping policy
- add keep-name controls for interop-sensitive symbols

### Later

- misleading-name strategies
- dictionary-based or AI-assisted semantic misdirection

## Acceptance Criteria

This coordination doc is doing its job when:

- rename priorities are easy to understand without reading a giant design doc
- each substantial rename subfeature has its own dedicated spec
- roadmap files can link here for rename direction and to child docs for
  implementation details

## Test Plan

This file does not define one implementation test plan. Each rename subfeature
must carry its own concrete test plan.

At the feature-family level, rename changes should continue to require:

- unit coverage for affected rename logic
- regression coverage for inheritance and dispatch-sensitive cases
- E2E validation on representative obfuscated builds

## Open Questions

- what should the official seed and reproducibility contract be?
- when should randomized generation become the default?
- should keep-name controls land before or after overloading?
- what is the right boundary between “harder to analyze” and “too complex to
  maintain” for rename behavior?

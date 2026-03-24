# Architecture Clarity

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.0`
**Related:** [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [../../architecture/pass-system.md](../../architecture/pass-system.md), [02-reporters.md](02-reporters.md), [03-github-reporter.md](03-github-reporter.md), [../README.md](../README.md)

## Goal

Make the current codebase architecture easier for contributors to understand and
extend without changing the product scope of `v0.2.0`.

## Scope

Included:

- document the current code-based architecture accurately
- reduce ambiguity around how new passes are added
- clarify the intended responsibility boundaries between CLI, config, engine,
  and pass modules
- identify and, when practical, isolate dense rename-pass orchestration logic

Not included:

- plugin or third-party extension systems
- large-scale engine rewrites
- changing pass behavior just to match a cleaner architecture
- public API stabilization beyond what `v0.2.0` already needs

## Acceptance Criteria

- contributors can find one accurate description of the current runtime
  architecture
- the codebase makes the pass registration/construction path easier to follow
- rename-pass safety logic is documented or decomposed enough that targeted
  changes do not require rediscovering hidden invariants
- architecture docs no longer describe already-removed pass-system concepts

## Test Plan

- verification through doc/code alignment review
- targeted tests if refactors move or split logic without changing behavior
- regression coverage for any touched rename-pass behavior

## Open Questions

- should pass construction stay as a built-in registry, or remain a small
  switch while the pass count is low?
- how much of rename safety should move into dedicated helper classes in
  `v0.2.0` versus later cleanup?

This feature is intentionally about execution clarity, not architectural
novelty. The project should prefer boring, explicit structures that help future
contributors make safe changes quickly.

---

## Problem

The current runtime flow is readable once you know where to look, but there are
still two contributor-facing friction points:

- the "how do I add a new pass?" path crosses config parsing, pipeline building,
  and exports without one obvious seam
- important rename-pass correctness rules are concentrated in a dense
  normalization step that is harder to reason about than the surrounding module
  structure suggests

There is also documentation drift risk when architecture docs describe older
designs after implementation has moved on.

---

## Desired Outcome

By the end of this feature:

- the current architecture docs match the current branch
- contributors can trace config -> pipeline -> pass execution with minimal
  guesswork
- pass-extension responsibilities are explicit
- rename-pass orchestration remains behaviorally identical but easier to review

---

## Candidate Changes

Possible work items within this feature:

- refresh the architecture review docs to match the current pass/result model
- add one small, named pass-registration seam and document it
- split rename-pass post-processing into dedicated helpers if that improves
  readability without broad churn
- add comments or narrowly scoped docs where invariants are easy to miss

The exact implementation can stay small. The goal is clarity, not framework
building.

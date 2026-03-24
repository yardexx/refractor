# Correctness Hardening

**Status:** implemented
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** current codebase baseline
**Related:** [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [../../architecture/rename-pass.md](../../architecture/rename-pass.md), [rename-foundation.md](rename-foundation.md)

## Goal

Capture the rename correctness hardening that is already present in the codebase
so we stop treating it as pending implementation work.

## Scope

Included:

- expanded rename coverage for tricky invocation and dispatch cases
- E2E confidence for rename-only and rename-plus-string-encrypt flows
- preservation of current runtime behavior while broadening rename safety

Not included:

- future rename capabilities such as overloading
- policy decisions like mapping modes or keep-name controls

## Acceptance Criteria

- relevant rename correctness work is present in the current codebase
- existing unit and E2E tests cover the broadened rename surface
- no known regression is introduced by the current implementation baseline

## Test Plan

- targeted regression coverage for covered handlers
- E2E smoke coverage for rename-only builds
- E2E smoke coverage for rename plus string-encrypt builds

## Open Questions

- should this stay as a standalone implemented doc, or be folded into
  `rename-foundation.md` later?

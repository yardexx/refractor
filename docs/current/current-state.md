# Current State

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** repository working tree
**Related:** [current-priorities.md](current-priorities.md), [current-decisions.md](current-decisions.md), [../../pubspec.yaml](../../pubspec.yaml)

## Goal

Provide one short source of truth for the project's current engineering state so
contributors and coding agents do not have to infer it from multiple roadmap
documents.

## Current Reality

- Package version in source control is `0.1.0`
- Internal docs already describe planned and partially implemented `v0.2.x` work
- Some roadmap entries describe work as shipped or feature-branch complete, but
  those claims should be verified against the current branch before relying on
  them
- Public README still presents the project as early-stage
- The current implementation focus inside `v0.2.0` is reporter integration:
  [../features/development/02-reporters.md](../features/development/02-reporters.md)

## Practical Rule

When sources disagree, use this order of precedence:

1. Current branch code
2. `pubspec.yaml`
3. `docs/current/`
4. Task-specific implementation docs
5. Roadmap and archive docs

## Working Assumptions

- Refractor is still in active development, not yet presented as a broadly
  stable release
- Rename and string-encrypt remain the primary production-facing capabilities
- End-to-end confidence matters more than adding new pass ideas quickly
- Docs should help contributors make safe changes without rediscovering context
- The active engineering task should be reflected in `docs/current/` whenever we
  move from planning into implementation

## Immediate Documentation Debt

- Align version and release language across docs and repository metadata
- Mark stale roadmap assertions as planned, branch-only, or released
- Normalize doc metadata headers
- Reduce broken internal links
- Keep the active `v0.2.0` implementation target in sync with
  `docs/features/development/`

## Exit Criteria For This File

Update this file whenever one of these changes:

- package version
- default target branch/release branch
- official release status
- current top priorities
- decision precedence rules

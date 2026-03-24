# Reporters

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-24
**Applies to:** `v0.2.0`
**Related:** [01-pass-statistics.md](01-pass-statistics.md), [03-github-reporter.md](03-github-reporter.md), [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [../README.md](../README.md)

## Goal

Introduce a dedicated reporting layer that consumes pass reports and renders
them for specific outputs without coupling formatting to CLI commands.

## Scope

Included:

- define reporter responsibilities
- move plain-text report formatting out of commands
- keep engine-layer report data presentation-free

Not included:

- changing pass execution models again
- GitHub-specific formatting or emission behavior
- server transport implementation

## Acceptance Criteria

- plain-text build formatting no longer lives directly in `BuildCommand`
- reporting behavior sits behind a clear abstraction
- reporter behavior has dedicated tests

## Test Plan

- unit tests for reporter output or formatting decisions
- regression checks that build-result data stays presentation-neutral

This is a follow-up to `01-pass-statistics.md`. That feature makes pass
execution results and structured reports available. This feature decides how
those reports are processed and presented.

---

## Problem

`BuildCommand` currently receives `BuildResult.reports`, but report formatting is
not yet settled.

We want a clean reporting seam without mixing formatting decisions into command
logic. We also do not want the first implementation to lock the project into a
GitHub- or transport-specific abstraction too early.

This first reporter feature should solve the generic formatting problem:

- plain-text summaries for humans
- omission of empty/no-op reports
- consistent failure rendering
- testable formatting logic outside commands

GitHub-specific output can build on this later as a dedicated follow-up.

---

## Desired Outcome

Add a reporting component with a clear responsibility:

- take structured pass reports and failures
- decide which reports are visible in the plain-text output
- format them as deterministic text
- keep engine-layer report data presentation-free

The architecture should make it obvious that:

- `PassReport` is data
- a reporter consumes data
- `BuildCommand` remains the side-effect boundary

---

## Proposed Design Direction

This feature should start with a small renderer-style contract, for example:

```dart
abstract class BuildReporter {
  String render(BuildResult result);
}
```

First implementation:

- `PlainTextBuildReporter`

Deferred follow-ups may add:

- `GitHubActionsBuildReporter`
- `JsonBuildReporter`

Decisions for `v0.2.0`:

- reporters consume full `BuildResult`
- reporters return strings; they do not log or write files directly
- `BuildCommand` owns printing, file writes, and exit codes

Open questions that may remain after this feature:

- how should metric labels be registered and evolved over time?
- should later reporters share one core formatter or diverge per output target?

---

## Temporary Status

Until this feature lands:

- `BuildCommand` may keep a TODO where report processing will be delegated later
- pass reports remain available in `BuildResult`
- exit code behavior based on pass failures remains in place

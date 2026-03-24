# GitHub Reporter

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-24
**Applies to:** `v0.2.0`
**Related:** [02-reporters.md](02-reporters.md), [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [../README.md](../README.md)

## Goal

Add a GitHub Actions oriented reporter that presents build results more clearly
in CI than plain terminal output alone.

## Scope

Included:

- define the first GitHub-specific reporting format for build results
- keep the GitHub formatter separate from generic plain-text reporting
- support CI-friendly emphasis for failed passes and useful summaries

Not included:

- server upload or hosted reporting
- GitHub Checks API integration
- pull-request review annotations tied to source files

## Acceptance Criteria

- GitHub-oriented formatting does not live directly in `BuildCommand`
- the GitHub formatter builds on the same `BuildResult` data used by the plain
  text reporter
- the output is clearly more CI-friendly than the plain terminal renderer
- reporter behavior has dedicated tests

## Test Plan

- unit tests for GitHub-formatted output
- regression checks that the generic reporter remains presentation-neutral
- command-level verification if a GitHub mode is wired into CLI behavior

## Open Questions

- should the first GitHub reporter target log output only, or GitHub Actions
  job summaries and annotations too?
- should GitHub-specific output be selected automatically in CI, or only via an
  explicit flag or environment check?

This feature follows `02-reporters.md`. That feature introduces the generic
rendering seam and plain-text build formatting. This feature adds a
GitHub-oriented renderer on top of the same build-result data.

---

## Problem

Plain CLI output is enough for local use, but CI logs benefit from stronger
visual structure:

- pass failures should stand out immediately
- summaries should be easy to scan in long job logs
- later GitHub-specific integrations should have a natural place to live

Without a dedicated GitHub-oriented renderer, CI output either stays too plain
or the command accumulates one-off formatting branches.

---

## Desired Outcome

By the end of this feature:

- generic reporting stays transport-neutral
- GitHub-specific formatting is isolated in its own renderer
- CI output can emphasize failures and useful summaries without contaminating
  the plain-text renderer

---

## Proposed Design Direction

Keep the same rendering contract introduced in `02-reporters.md`, for example:

```dart
abstract class BuildReporter {
  String render(BuildResult result);
}
```

Then add a dedicated implementation such as:

```dart
final class GitHubActionsBuildReporter implements BuildReporter {
  @override
  String render(BuildResult result) {
    // GitHub Actions oriented formatting.
  }
}
```

Possible output directions:

- grouped plain text optimized for Actions logs
- GitHub-flavored markdown for job summaries
- later, explicit annotation formatting if the behavior is clearly defined

The key rule is:

**GitHub-specific formatting belongs in its own reporter, not in
`BuildCommand`.**

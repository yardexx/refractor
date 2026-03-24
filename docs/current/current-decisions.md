# Current Decisions

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** default collaboration and implementation decisions
**Related:** [current-state.md](current-state.md), [../architecture/pass-system.md](../architecture/pass-system.md)

## Accepted Working Decisions

### 1. Source Of Truth Precedence

Until the docs are fully normalized, trust sources in this order:

1. code on the active branch
2. `pubspec.yaml`
3. `docs/current/`
4. implementation specs
5. roadmap and archive docs

### 2. Documentation Standard

New docs should be short, decision-oriented, and explicit about status.
Exploration belongs in roadmap, research, or archive docs, not in the main
index.

### 3. Roadmap Structure Standard

Roadmap planning should use exactly three active planning levels:

1. one long-term product-plan file
2. one version-overview file for a version line
3. one concrete release file for the next release being executed

Do not mix strategic planning, version-family planning, and concrete release
scope in one roadmap document again.

### 4. Collaboration Standard

A task is not complete until it includes:

- code or doc change
- verification step
- explicit note of assumptions or unresolved risk

### 5. Feature Work Standard

Before significant implementation, every feature should have:

- a scoped doc or issue
- acceptance criteria
- a test plan
- a callout for out-of-scope items

### 6. Active Execution Tracking Standard

When implementation is actively underway, `docs/current/` should name the
current feature being executed and point to its development spec directly.

Current active implementation target:

- [../features/development/02-reporters.md](../features/development/02-reporters.md)

## Decisions Still Missing

These need ADRs or explicit project-level agreement:

- supported Dart SDK and kernel compatibility policy
- release branch strategy vs package versioning policy
- default mapping policy: stable or rotating
- seed and reproducibility contract
- canonical pass ordering and whether user config may override it
- crash-reporting artifact format and first integration target
- performance budgets for compile time, runtime, and binary size
- plugin strategy: internal registry only or public extension surface

# Product Plan

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** long-term product planning
**Related:** [v0.2-overview.md](v0.2-overview.md), [../product/product-brief.md](../product/product-brief.md), [../research/research-trends-2026.md](../research/research-trends-2026.md)

## Purpose

This file is the long-term product plan.

Use it for:

- major themes and sequencing
- why a feature area matters
- rough version-family direction
- backlog-level bets

Do not use it for:

- detailed feature definitions
- concrete release scope
- day-to-day execution tracking

Those belong in the version overview or a single release file.

## Planning Principles

- First make existing passes trustworthy before adding more surface area
- Remove adoption barriers early, especially crash reporting and reproducibility
- Prefer boring, maintainable architecture over clever feature growth
- Only elevate a transform when we understand its optimizer resistance and test
  story

## Long-Term Direction

### Phase 1: Foundation

Focus: make rename and string encryption production-trustworthy.

Key outcomes:

- end-to-end confidence
- better reporting and build artifacts
- cleaner engine boundaries
- crash-reporting compatibility

Primary version line:

- [v0.2-overview.md](v0.2-overview.md)

### Phase 2: Structural Defense

Focus: add transforms that change structure, not just names.

Candidate areas:

- pass registry and ordering
- control-flow flattening
- string array indirection
- performance and resistance benchmarks

Target version family:

- `v0.3.x`

### Phase 3: DX And Ecosystem

Focus: make Refractor usable in real-world workflows.

Candidate areas:

- symbolication and crash-reporting docs/integration
- keep-name controls
- DevTools-based visibility into build output
- richer build summaries

Target version family:

- `v0.4.x`

### Phase 4: Advanced Transforms

Focus: add selective higher-cost transforms after the basics are stable.

Candidate areas:

- arithmetic substitution
- method outlining
- misleading-name strategies

Target version family:

- `v0.5.x`

### Phase 5: Integration And Distribution

Focus: reduce adoption friction and support broader packaging workflows.

Candidate areas:

- Flutter build integration
- package distribution mode
- target-specific defaults

Target version family:

- `v0.6.x`

## Strategic Bets

- Crash reporting remains the biggest adoption blocker
- Name-only obfuscation will not stay competitive against AI-assisted reverse
  engineering
- The kernel-level position remains a meaningful differentiator, but it also
  increases compatibility risk with Dart SDK changes

## Backlog Themes

These are worth keeping visible, but they are not current commitments:

- AI-assisted misleading rename
- integer constant encoding with runtime anchoring
- code virtualization
- anti-AI semantic noise
- plugin or third-party pass architecture
- before/after binary diff tooling
- performance optimization of analysis-heavy passes

## Rules For This File

- Keep this file high level
- Summarize by theme and version family, not by individual issue checklist
- Link down to `vX.Y-overview.md` or `vX.Y.Z.md` for execution detail

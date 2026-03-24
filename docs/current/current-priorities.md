# Current Priorities

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** near-term project planning
**Related:** [current-state.md](current-state.md), [../roadmap/product-plan.md](../roadmap/product-plan.md), [../roadmap/v0.2-overview.md](../roadmap/v0.2-overview.md)

## Priorities

1. Finish `v0.2.0` confidence and reporting work, with reporter integration
   next after the pass-statistics data model, followed by GitHub-oriented CI
   output.
2. Make the existing rename and string-encrypt pipeline trustworthy through
   E2E, resistance, and regression coverage.
3. Improve contributor clarity around current architecture and pass-extension
   seams while `v0.2.0` work is still active.
4. Reduce adoption friction with symbolication and crash-reporting workflows.
5. Keep future-pass research, but do not let speculative roadmap work outrun
   current correctness guarantees.

## Near-Term Work Themes

- release-truth cleanup
- docs and collaboration scaffolding
- pass reporting and build artifacts
- GitHub-oriented CI reporting
- architecture clarity and extension-path cleanup
- active implementation target:
  [../features/development/02-reporters.md](../features/development/02-reporters.md)
- crash-reporting compatibility
- reproducibility and mapping policy

## Prioritization Heuristics

Choose work that:

- improves correctness or confidence for existing passes
- removes ambiguity for contributors
- makes future decisions easier, not harder
- has a clear test plan

Deprioritize work that:

- adds a new obfuscation layer without clear survival evidence
- depends on unresolved mapping or ordering decisions
- expands roadmap surface area without operational docs

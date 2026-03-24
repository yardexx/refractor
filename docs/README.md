# Refractor Internal Docs

Internal design and planning docs for contributors and coding agents.

This folder is intentionally split by document role. Not every file here is a
source of truth.

## Start Here

If you are about to work on the codebase, read these first:

1. [current/current-state.md](current/current-state.md)
2. [current/current-priorities.md](current/current-priorities.md)
3. [current/current-decisions.md](current/current-decisions.md)
4. Relevant architecture or active spec docs for the task

If the current docs disagree with older roadmap or feature docs, prefer
`docs/current/` and the code.

## Folder Roles

```text
docs/
├── current/        Current truth for active work
├── architecture/   Stable technical reference
├── product/        Positioning, demos, adoption story
├── research/       External landscape and source material
├── roadmap/        Release planning and sequencing
└── archive/        Historical or superseded material
```

## What To Read By Task

For onboarding:
- [current/current-state.md](current/current-state.md)
- [../README.md](../README.md)
- [architecture/architecture-review.md](architecture/architecture-review.md)
- [architecture/pass-system.md](architecture/pass-system.md)

For rename-pass work:
- [architecture/rename-pass.md](architecture/rename-pass.md)
- [features/implemented/rename-foundation.md](features/implemented/rename-foundation.md)
- [features/future/rename-improvements.md](features/future/rename-improvements.md)
- [current/current-decisions.md](current/current-decisions.md)

For string-encrypt work:
- [features/implemented/string-encrypt-foundation.md](features/implemented/string-encrypt-foundation.md)
- [features/future/string-encrypt-improvements.md](features/future/string-encrypt-improvements.md)
- [features/development/05-resistance-tests.md](features/development/05-resistance-tests.md)
- [current/current-decisions.md](current/current-decisions.md)

For roadmap and sequencing:
- [current/current-priorities.md](current/current-priorities.md)
- [roadmap/product-plan.md](roadmap/product-plan.md)
- [roadmap/v0.2-overview.md](roadmap/v0.2-overview.md)
- [roadmap/v0.2.0.md](roadmap/v0.2.0.md)

For product context:
- [product/product-brief.md](product/product-brief.md)
- [research/research-landscape.md](research/research-landscape.md)

## Document Rules

Every new internal doc should include:

- `Status`: draft, active, accepted, superseded, or archived
- `Owner`: who should update it
- `Last reviewed`: date
- `Applies to`: branch, version, or milestone
- `Related`: links to adjacent docs or ADRs

Recommended section order:

1. Goal
2. Scope
3. Decision or proposal
4. Acceptance criteria
5. Test plan
6. Open questions

Use the metadata and section structure from existing docs in
`features/development/`, `features/future/`, and `roadmap/` until dedicated
templates are added back to the repository.

## Current Gaps To Keep In Mind

These are still the most important open concerns for contributors:

- Release status is split across docs and code metadata
- Crash-reporting integration is not landed yet
- Some architecture and product docs may lag behind the current branch if they
  are not refreshed alongside implementation changes
- Several roadmap items were written before later rename/string work landed
- Not all roadmap docs have been normalized to the new structure yet

## Migration Notes

The existing `features/` tree remains in place for now to avoid breaking context
while work is active. The next cleanup step should be to migrate active
implementation specs into `docs/specs/active/` and move older exploratory docs
into `docs/specs/future/` or `docs/archive/`.

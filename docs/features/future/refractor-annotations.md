# Refractor Annotations

**Status:** future
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** post-`v0.2.x` feature control design
**Related:** [rename-improvements.md](rename-improvements.md), [../../roadmap/product-plan.md](../../roadmap/product-plan.md)

## Goal

Provide a small annotation library that lets developers control Refractor
behavior declaratively in source code instead of relying only on external config
files.

The purpose of this doc is to capture the broader concept first. Exact
annotation names, scope, and pass-specific behavior should be decided later.

## Scope

Included:

- the concept of a dedicated Refractor annotation library or package
- annotation-based control over obfuscation behavior
- the likely target surface for those annotations
- open design questions that must be resolved before implementation

Not included:

- final annotation names
- final pass-specific semantics
- implementation details for a single pass only

## Why This Exists

Some obfuscation decisions belong close to the code they affect.

Annotations would make it possible to mark declarations in a way that:

- travels with the code
- is visible during review
- avoids fragile path- or name-based config patterns
- gives developers a clearer escape hatch for special cases

This is especially useful for declarations whose names or behavior must stay
stable because of:

- dynamic lookup
- interop or entry-point expectations
- generated code integration
- framework conventions
- future pass-specific exclusions

## Possible Target Surface

The annotation system may eventually apply to:

- classes
- methods and procedures
- fields and properties
- constructors
- top-level functions and variables
- extensions or extension types
- possibly whole libraries later

The exact supported surface should be decided only after reviewing which passes
can consume annotations safely and consistently.

## Possible Capabilities

Annotations may eventually control one or more of:

- exclusion from renaming
- exclusion from string encryption
- exclusion from future structural passes
- keep-name or keep-members behavior
- pass-specific opt-in or opt-out behavior
- stricter handling for symbols that must remain externally stable

This doc intentionally does not decide which of these ship first.

## Design Principles

- annotations should be understandable without reading internal Refractor code
- the system should be conservative by default
- annotation behavior should be explicit and testable
- the annotation package should stay small and boring
- annotations should complement config-based controls, not create a second
  conflicting policy system
- prefer a predictable public API over a growing set of narrowly named
  annotations

## API Shape Discussion

Two broad directions are currently on the table:

- a single specific annotation, similar to the Guardsquare / ProGuard style
- a namespaced annotation like `@Refractor.keep(...)` with a small enum-based
  configuration

Current recommendation:

- prefer `@Refractor.keep(...)` as the main public entry point
- keep the first version intentionally small and boring
- use enum-like options rather than strings or a mini-DSL
- avoid pass-specific knobs in the first design

Why this is the leading direction:

- one stable public annotation scales better as Refractor gains more passes
- it keeps the package easier to document and easier to evolve
- it avoids a future explosion of narrowly scoped annotations like
  `@KeepName`, `@KeepMembers`, and similar variants
- it matches the broader goal of making the architecture predictable and easy
  to understand

Possible early shapes:

- `@Refractor.keep()`
- `@Refractor.keep(KeepTarget.self)`
- `@Refractor.keep(KeepTarget.members)`
- `@Refractor.keep(KeepTarget.all)`

Or, if multiple targets are needed later:

- `@Refractor.keep([KeepTarget.self, KeepTarget.members])`

Important constraint:

- this doc records the preferred API direction, but it does not yet lock in
  the final annotation names, enum names, or first-release semantics

## Major Open Decisions

- should the first release of annotations be rename-only, or intentionally
  pass-agnostic from the start?
- what is the precedence order between annotations and config file excludes?
- should annotations support broad scopes like “keep all members” or only
  narrow declaration-level controls at first?
- should there be one generic annotation model or several pass-specific ones?
  Current lean: one generic public entry point.
- how should generated code and third-party package code interact with the
  annotation model?

## Dependencies

Before implementation, we should settle:

- mapping and rename policy boundaries
- the desired pass-exclusion model
- how annotations are resolved in the engine
- how annotation semantics are tested across passes

## Acceptance Criteria

- the annotation feature has a clear, stable purpose before implementation
- supported declaration targets are explicitly documented
- precedence with config-based controls is defined
- the first shipped annotation set is intentionally scoped, not open-ended

## Test Plan

This is not yet an implementation test plan.

When implemented, tests should cover:

- supported declaration targets
- precedence and conflict resolution
- pass-specific behavior where annotations are consumed
- behavior on code that should remain unchanged without annotations

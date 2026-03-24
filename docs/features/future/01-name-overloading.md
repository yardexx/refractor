# Name Overloading

**Status:** planned
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.2` candidate scope
**Related:** [../../roadmap/v0.2-overview.md](../../roadmap/v0.2-overview.md), [rename-improvements.md](rename-improvements.md)

## Goal

Reuse the same short names across unrelated class hierarchies. Two methods in
unrelated classes get the same obfuscated name, defeating search-replace
deobfuscation. This applies only to instance members, never top-level, static,
or constructor members.

## Scope

Included:

- override-family-aware name allocation
- graph-coloring or equivalent slot reuse across unrelated hierarchies
- safety rules for inheritance and dispatch correctness
- tests that prove overloading does not break polymorphism

Not included:

- top-level or static overloading
- constructor overloading changes
- misleading-name strategies

## Acceptance Criteria

- instance members in unrelated hierarchies may share one obfuscated name
- members in the same override family always keep one shared safe name
- runtime dispatch remains correct across covered inheritance cases
- tests cover collision safety and inheritance-sensitive cases

## Test Plan

- unit tests for override-family construction
- unit tests for slot allocation and conflict detection
- regression tests for inheritance, interfaces, and mixins
- E2E smoke validation on representative rename fixtures

## Open Questions

- should overloading be behind a dedicated config flag or part of the default
  rename strategy?
- how should slot assignment interact with future randomized name generation?

## Current Architecture

The current rename pass already follows a multi-step pipeline:

1. **Policy resolution** — `ObfuscationPolicyResolver` decides what is safe to
   rename.
2. **Planning** — `RenamePlanner` collects classes, singleton members,
   variables, and override-sensitive member families.
3. **Slot building** — `RenameSlotBuilder` turns the plan into naming slots.
4. **Name generation + materialization** — a `NameGenerator` produces raw names
   and `NameMaterializer` turns them into a `RenameMapping`.
5. **Safety normalization** — `RenamePass` performs extra reconciliation for
   dynamic dispatch and callable-surface preservation.
6. **Apply** — `RenameTransformer` mutates declarations and call sites.

So this feature is no longer about introducing override-family-aware
architecture from scratch. It is about adding safe slot reuse on top of the
current planner/slot/materializer pipeline.

---

## Prerequisites

Name overloading requires **override family analysis** — grouping instance members that must share one name due to inheritance/interface relationships. Without this, overloading would silently break polymorphic dispatch.

This prerequisite is a significant refactor of the rename pass. Two approaches:

### Current Position

The project is already much closer to the old "Option B" than "Option A". The
remaining design work is about extending the existing planning/allocation path
without weakening the current safety rules.

---

## Algorithm: Graph Coloring on Override Families

Once override families exist, overloading is a graph coloring problem:

1. **Build conflict graph:** Two override families conflict if any declaring class in family A is related (ancestor/descendant) to any declaring class in family B (checked via class hierarchy index).
2. **Greedy coloring:** Sort families by conflict count descending. Assign each family the lowest color (integer slot) not used by any conflicting neighbor.
3. **Map slots to names:** Generate one name per unique slot. All families sharing a slot get the same obfuscated name.

---

## Files to Create

### `lib/src/engine/passes/rename/override_family/class_relation_index.dart`

Precomputed class hierarchy — supertypes (transitive, including external), subtypes (scoped to collected classes). Provides:
- `areRelated(Class a, Class b)` — is A an ancestor/descendant of B?
- `shareDeclaringSupertypeForName(Class a, Class b, String name)` — do A and B share a common supertype that declares a member with this name?

### `lib/src/engine/passes/rename/override_family/override_family_analyzer.dart`

Groups instance members into override families using Union-Find (`DisjointSet`). Two members in different classes get unioned if:
- Their classes are directly related (parent/child), OR
- They share a common supertype that declares a member with the same name

### `lib/src/engine/passes/rename/override_family/override_families.dart`

Data model:
- `OverrideFamily` — a set of members that must share one name, with a root member, privacy flag, and library scope
- `OverrideFamilies` — list of families + `familyOf` lookup map

### `lib/src/engine/passes/rename/name_overloader.dart`

Graph coloring. Input: `OverrideFamilies` + `ClassRelationIndex`. Output: `Map<OverrideFamily, int>` (family → slot index).

### `lib/src/utils/disjoint_set.dart`

Generic Union-Find data structure with path compression and union-by-rank.

---

## Files to Modify

### `lib/src/engine/passes/rename/rename_pass.dart`

Replace the current two-phase approach with a multi-phase pipeline:
1. Collect declarations (new `DeclarationCollector` or refactored `RenameVisitor`)
2. Build class hierarchy (`ClassRelationIndex`)
3. Analyze override families (`OverrideFamilyAnalyzer`)
4. Optionally compute overloading slots (`NameOverloader`)
5. Generate names (new `NameAllocator` or modified `NameGenerator`)
6. Apply (`RenameTransformer` — mostly unchanged)

### Config layer

Wire an `enableOverloading` flag from `RenamePassConfig` into
`RenamePassOptions`, then into the planner/allocation path through
`PipelineBuilder`.

---

## Critical Safety Rule

**Overloading applies ONLY to override families (instance members), never singletons (top-level, static, constructors).**

A previous implementation had a bug where singleton families (top-level functions) with empty class sets always appeared non-overlapping in the conflict graph, causing all top-level functions to collapse to the same name. The `NameOverloader` must only operate on `OverrideFamilies.families`.

---

## Tests

### Unit: Override Family Analysis
- Two unrelated classes with same-named methods → separate families
- Parent/child classes with overridden method → same family
- Interface implementation → same family
- Mixin application → same family
- Diamond inheritance → correct family grouping

### Unit: Name Overloader
- Unrelated families → same slot
- Related families → different slots
- Single family → slot 0
- Empty input → empty result

### Unit: DisjointSet
- Union/find operations
- Path compression
- Connected components

### Integration: Rename Pass
- Overloading enabled: unrelated classes' methods share names
- Overloading disabled: all families get distinct names (backward compat)
- Singletons always get unique names regardless of overloading flag
- Existing E2E smoke test still passes

---

## Verification Checklist

- [ ] `dart analyze` — zero warnings
- [ ] `dart test` — all tests pass
- [ ] E2E smoke test — correct output with overloading enabled and disabled
- [ ] No singleton names collapse
- [ ] Override families are correct across inheritance/interface/mixin

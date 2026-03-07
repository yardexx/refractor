# Feature: Rename Pass Improvements

Planned improvements for the rename pass. All techniques in this document are structural transforms (changing identifiers), not expression-level transforms — they **always survive** the Dart VM optimizer.

Improvements are organized into three tiers by the type of confusion they create for an attacker.

---

## Tier 0 — Strip Meaning (current)

Remove original names and replace with short sequential identifiers. Attacker immediately knows the binary is obfuscated but loses all semantic information.

### 0.1 Local Variable & Parameter Renaming

**Status:** Implemented in v0.1.0.

Rename `VariableDeclaration.name` for local variables and function parameters to short reusable names (`a`, `b`, `c`). Safe because kernel uses identity-based references (`VariableGet.variable` points to the declaration object), not name-based lookups.

Names can be reused across unrelated scopes — each `VariableDeclaration` is a distinct object even if they share the `.name` string.

### 0.2 Static Call Site Handling

**Current gap:** The rename pass updates instance dispatch sites (`InstanceGet`, `InstanceSet`, `InstanceInvocation`, etc.) but does not handle static member references.

**What to handle:**
- `StaticGet` — reading a static field or top-level variable
- `StaticSet` — writing a static field or top-level variable
- `StaticInvocation` — calling a static method or top-level function

Static call sites reference the target `Member` directly by object identity, so renaming the member's `name` property is sufficient — no name field on the call site needs updating. However, canonical names must be invalidated after rename so `BinaryPrinter` recomputes them correctly.

**Canonical name invalidation mechanism (current implementation):**
- After rename transform, iterate obfuscated user libraries and call `lib.reference.canonicalName?.unbindAll()`.
- This removes stale canonical-name bindings rooted at each renamed library.
- `BinaryPrinter.writeComponentFile` then rebuilds canonical names from the mutated AST while writing output.

**Risk:** Low. Static dispatch in kernel is identity-based, not name-based.

### 0.3 Constructor Invocation Handling

**What to handle:**
- `ConstructorInvocation` — `MyClass()` or `MyClass.named()`
- `SuperInitializer` — `super()` or `super.named()`
- `RedirectingInitializer` — `this()` or `this.named()`

Like static calls, constructor invocations reference the `Constructor` member by identity. Ensure canonical name invalidation covers constructors.

### Tier 0 Acceptance Criteria

- Rename pass handles `StaticGet`, `StaticSet`, `StaticInvocation`, `ConstructorInvocation`, `SuperInitializer`, and `RedirectingInitializer` without runtime behavior changes.
- Canonical names are invalidated and recomputed during binary writing for all renamed members, including constructors.
- Build output is functionally equivalent to baseline across existing integration tests.
- Symbol table (if enabled) contains complete old->new mapping for every renamed declaration in Tier 0 scope.

---

## Tier 1 — Hide Structure

Make structural analysis harder. Attacker still knows the binary is obfuscated, but cannot distinguish declarations by name or infer rename order.

### 1.1 Name Overloading (ProGuard-style)

**Current behavior:** Each declaration gets a unique sequential name (`_$0`, `_$1`, `_$2`, ...). A reverser can distinguish any two declarations by name.

**Improvement:** Reuse the same short names (`a`, `b`, `c`) across unrelated classes. Two methods in different classes can share a name without conflict because dispatch uses receiver type + method name.

**Collision safety rules:**
- Two instance members can share a name only if their declaring classes have no subclass relationship
- A field and a getter/setter with the same name in the same class must share the name (already handled by deduplication)
- Top-level functions in different libraries can share names
- Override-family rule is transitive through interfaces/mixins: if two members are connected by override equivalence (even via an interface-only edge), they must share one obfuscated name.

**Expanded language-surface rules (implementation guardrails):**
- Preserve override compatibility: members in the same override family (base class, subclass, interface implementation, mixin application) must get the same renamed symbol where dispatch requires it.
- Compute override families using transitive closure across superclass, interface, and mixin edges; do not rely on direct subclass checks alone.
- Preserve getter/setter pairing semantics across inheritance. If a getter/setter pair is logically the same property, keep names aligned.
- Treat operators and special members conservatively (`[]`, `[]=`, unary/binary operators, `call`): rename only when proven safe by kernel constraints and test coverage.
- Constructors remain unique within a class by signature and kind (generative/factory); named constructors must avoid collisions with other named constructors in the same class.
- Respect library privacy boundaries: private names (`_x`) are library-scoped. Reuse across libraries is allowed; collisions within a library namespace are not.
- Extensions/extension types (if present in input) must be included in collision analysis so member lookup remains valid.
- Enum members and synthesized members are only renamed when explicitly allowed by the same safety validation pipeline.

**Effect:** Searching for `a` returns hundreds of results across unrelated classes, defeating search-replace deobfuscation.

### 1.2 Randomized Name Generation

**Current behavior:** Names are generated sequentially (`_$0`, `_$1`, ...), making the rename order visible and predictable.

**Improvement:** Use a seeded `Random` to generate names from a pool of short identifiers. The seed provides reproducibility for debugging while the output looks non-sequential.

**Name pool options:**
- Single characters: `a`-`z`, `A`-`Z` (52 names, then combinations)
- Short combinations: `aa`, `ab`, ..., `zz` (676 names)
- Underscore-prefixed for private: `_a`, `_b`, ...

**Seed behavior:** Default seed derived from project name hash. Optional `--seed` CLI flag for exact reproducibility.

**Determinism contract:**
- With the same input kernel + same config + same tool version + same seed, output rename map is byte-for-byte stable.
- Rename assignment must not depend on host-specific iteration order. Use explicit stable ordering keys (e.g., library URI, declaration kind, canonical path/signature).
- Adding unrelated declarations should not reshuffle all existing names.
- Mechanism: derive each declaration's candidate stream from `hash(seed + stableDeclarationKey)` rather than a single global PRNG sequence.
- `stableDeclarationKey` should be canonical and deterministic (library URI + owner path + declaration kind + signature bucket).
- Resolve rare collisions with deterministic probing (`attemptIndex`), preserving locality for unrelated declarations.
- When deterministic behavior changes between tool versions, release notes must state this and bump an obfuscation-strategy version identifier.
- `--seed` must fully override default seed derivation and be recorded in build metadata/symbol table for reproducibility.

### Tier 1 Acceptance Criteria

- Name overloading is enabled and validated against collision rules across inheritance/interface/mixin relationships.
- Randomized generation produces non-sequential names while remaining reproducible under deterministic contract.
- Golden tests show stable output for repeated runs with fixed seed.
- Cross-library and private-name behavior matches Dart visibility semantics.

---

## Tier 2 — Actively Mislead

Replace original names with **plausible but wrong** semantic names. Attacker does not immediately recognize obfuscation and is led down false paths during analysis. This is the highest-value tier — it turns reverse engineering from "tedious" into "unreliable."

### 2.1 Structural Context Collection

Before renaming, collect a structural summary of the program:
- **Classes** — name, field count, method signatures (parameter count, return type shape)
- **Methods/Functions** — name, arity, whether async/sync, return type
- **Call graph** — which methods call which other methods (outgoing references)
- **File/library names** — for additional context on the original domain

This metadata drives name assignment — it is never emitted into the output binary.

### 2.2 Dictionary-Based Misleading Rename (local, deterministic)

Map structural shapes to a curated dictionary of misleading but plausible names, organized by "fake domain" (networking, database, UI, caching, logging, etc.).

**How it works:**
1. Categorize each class by its structural shape (e.g., "3 methods, 1 field, uses Future")
2. Assign the class to a fake domain different from its real one (e.g., a crypto class becomes `ImageCacheManager`)
3. Rename its members using domain-consistent names (e.g., `encrypt()` -> `resizeImage()`, `key` -> `aspectRatio`)
4. Ensure consistency within a class — all names come from the same fake domain

**Cross-class coherence for dictionary mode:**
- Build weakly connected components from the class-level call graph.
- Assign one primary fake domain per component (or a constrained compatible domain set) so direct call neighbors do not produce obviously contradictory narratives.
- Allow intentional domain boundaries only at component boundaries; avoid random per-class domain switching inside one connected component.

**Collision safety:** Same rules as Tier 1 overloading, plus ensure no two classes in the same library get assigned to the same fake domain with the same class name.

**Seed behavior:** Same as Tier 1 — seeded random selects which fake domain maps to which real class. Reproducible builds, different-looking output per seed.

**Dictionary maintenance:** Ship a built-in dictionary covering common domains (networking, UI, database, file I/O, caching, auth, logging, serialization). Each domain entry provides: class name templates, method name templates (by arity), field name templates.

**Security/clarity policy:**
- Misleading names are allowed to leak *surface semantics* (class/method/function labels may look plausible).
- Misleading names must not leak *true implementation intent or logic*. Any generated name that materially reflects real behavior is considered a policy violation and must be replaced.
- Developer-facing docs and flags should explicitly state this goal: "obfuscation may expose synthetic naming narratives, but must not expose real implementation meaning."

### 2.3 AI-Assisted Misleading Rename (optional, non-deterministic)

Use an LLM to generate contextually misleading names from the structural summary.

**How it works:**
1. Collect structural summary (same as 2.1)
2. Send summary to LLM with prompt: "Generate plausible but incorrect names for these declarations. The names should suggest a completely different domain than the actual code."
3. LLM returns a rename map
4. Apply the map using the same rename infrastructure

**Advantages over dictionary:**
- Can produce more creative and varied misleading names
- Can consider cross-class relationships for a more coherent fake narrative
- Adapts to unusual code shapes that don't fit dictionary templates

**Drawbacks:**
- Network dependency — requires API access at build time
- Non-deterministic — same input may produce different names across builds
- Cost — API call per build
- Risk of accidentally producing correct or near-correct names

**Mitigation:** Cache the generated rename map alongside the symbol table. Re-use cached map unless code structure changes. Optional `--rename-strategy=ai` flag — not the default.

**AI context modes:**
- `--ai-context=anonymous` (recommended default): send only structural metadata (shape, arity, graph features), not full declaration names/content.
- `--ai-context=full`: allow richer context for better narrative coherence when user accepts higher leakage risk.

**Provider behavior:**
- If provider is remote/online, emit a clear build warning describing potential metadata exposure.
- Support local model providers to avoid network transmission of program structure.

**Validation and fallback requirements (Tier 2 hard safety):**
- Validate every candidate name before apply:
  - legal Dart identifier for target context
  - not a reserved keyword
  - conforms to private/public prefix rules (`_` only when valid for library scope)
  - no collision after full inheritance + library namespace analysis
- Run policy filter to reject names that are too semantically close to original identifiers (to avoid leaking true intent).
- If AI response is partial/invalid, fall back to dictionary strategy for affected declarations; build must not fail by default.
- Provide strict mode (`--rename-strict`) to fail build on any Tier 2 validation rejection.
- Persist rename map cache keyed by structural fingerprint + strategy version + seed/config to avoid accidental drift.

### Tier 2 Acceptance Criteria

- Dictionary strategy produces policy-compliant misleading names with deterministic output under fixed seed.
- AI strategy is opt-in, passes validation pipeline, and has deterministic cache reuse behavior for unchanged structure.
- Rejected/invalid names are safely replaced by fallback strategy without breaking build (unless strict mode enabled).
- No accepted rename violates collision, visibility, or identifier legality rules.

---

## Implementation Priority

1. **Tier 0.2, 0.3** — Complete coverage of rename targets (prerequisite for everything else)
2. **Tier 1.1, 1.2** — Low effort, high impact on automated analysis
3. **Tier 2.2** — Dictionary-based misleading rename (80% of Tier 2 value, zero dependencies)
4. **Tier 2.3** — AI-assisted rename (optional enhancement, behind a flag)
5. **Keep rules/annotations** — Add annotation library and keep-rule support before broad Tier 2 rollout
6. **Mapping mode policy** — Add stable vs rotating mapping mode controls for release strategy

---

## Validation & Test Matrix

### A. Correctness (all tiers)

- AST/kernel integrity tests: all references resolve after rename; no dangling targets.
- Runtime parity tests: obfuscated build passes the same functional tests as non-obfuscated build.
- Constructor/static coverage tests: explicit fixtures for every node listed in Tier 0.2 and 0.3.

### B. Collision and language semantics

- Inheritance graph tests: base/interface/mixin override families keep dispatch-correct naming.
- Transitive interface tests: unrelated concrete classes implementing the same interface method stay in one override family naming group.
- Getter/setter/property tests: paired semantics preserved across class hierarchies.
- Library privacy tests: private/public naming obeys library scope constraints.
- Specialized members tests: operators, `call`, enums, extensions (when enabled) remain valid.
- FFI/entry-point safety tests: declarations marked with `@pragma('vm:entry-point')`, FFI entrypoints, and explicit keep-rules are not renamed.

### C. Determinism and reproducibility

- Fixed-seed repeatability: N repeated runs produce identical rename map/output.
- Reordering resilience: declaration reorder in source does not cause broad rename churn.
- Incremental-change locality: adding unrelated declarations does not rename unrelated existing symbols.
- Versioned behavior tests: strategy/version bump clearly separates expected mapping changes.

### D. Tier 2 policy and safety

- Leakage policy tests: accepted names must not match/approximate original implementation semantics beyond configured threshold.
- Validation tests: reject illegal identifiers, keywords, visibility violations, and collisions.
- AI fallback tests: partial/invalid AI output is replaced by dictionary names deterministically.
- Cache tests: unchanged structural fingerprint reuses rename map; changed fingerprint invalidates.

### E. Non-functional gates

- Performance budget: rename phase time and memory overhead within defined target thresholds.
- Artifact checks: symbol table/cache files are complete, parseable, and versioned.
- CI gate: Tier-specific test suites are mandatory before merging strategy changes.

---

## Scope Boundaries (Current)

- Out of scope for this feature: access control and secret-management policy for exported symbol maps/artifacts.
- Out of scope for this feature: CI/repo tamper-resistance and broader supply-chain hardening controls.
- Out of scope for this feature: repository-level metadata leakage controls (debug artifact governance, release telemetry governance).
- Assumption: these concerns are handled at repository/organization access-control level.

## Rename Target Scope

- In scope now:
- Class names.
- Member names (fields/procedures).
- Local variable and parameter names.
- Related static/constructor dispatch coverage in Tier 0.2/0.3.
- Deferred (explicitly out of current tier scope unless enabled later):
- Typedef names.
- Extension/extension type declaration names.
- Other type-level aliases/synthetic names not listed above.

## Annotation & Mapping Policy

### Keep-name annotation library

- Ship a lightweight annotation package to opt declarations out of renaming where dynamic lookup/reflection requires stable symbols.
- Minimum annotations:
  - `@Refractor.keepName()` — preserve declaration symbol.
  - `@Refractor.keepMembers()` — preserve all members of a class/extension where needed.
- Rename pass must honor annotations before any Tier 1/Tier 2 allocation.

### Mapping stability modes

- `--mapping-mode=stable`: deterministic mapping for reproducible debugging and symbolication continuity.
- `--mapping-mode=rotating`: per-release mapping variation (seed diversification) to reduce cross-release differential analysis.
- Both modes must remain functionally equivalent; mode only affects rename allocation policy, not program semantics.

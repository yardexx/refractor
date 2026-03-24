# Misleading-Name Strategies

**Status:** future
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** post-`v0.2.x` rename hardening
**Related:** [rename-improvements.md](rename-improvements.md), [../../roadmap/product-plan.md](../../roadmap/product-plan.md)

## Goal

Move beyond meaningless rename output and instead assign plausible but wrong
 names that actively mislead human and AI-assisted reverse engineering.

This is a Tier 2 rename idea. It should only be considered after correctness,
mapping policy, and safer Tier 1 rename features are solid.

## Scope

Included:

- dictionary-based misleading rename
- AI-assisted misleading rename
- validation, fallback, and policy constraints for misleading names

Not included:

- implementing networked AI workflows by default
- weakening current correctness or reproducibility guarantees

## Why This Exists

Meaningless names remove semantics, but they also clearly signal
"this binary is obfuscated." Misleading-name strategies try to go further by
creating false semantic narratives.

Example intent:

- a crypto helper might be renamed to something that looks image-related
- a calculation method might be renamed to something that looks like caching
- a service class might look like a UI utility

The objective is not just to hide meaning, but to send analysis in the wrong
direction.

## Strategy A: Dictionary-Based Misleading Rename

Use a curated local dictionary of fake domains and assign structurally plausible
but incorrect names deterministically.

Possible approach:

1. collect a structural summary of declarations
2. group related declarations or classes
3. assign a fake domain such as networking, UI, caching, logging, or storage
4. rename classes, methods, and fields using templates from that fake domain

Design requirements:

- deterministic under fixed seed
- collision-safe under full rename validation
- coherent enough that directly related classes do not tell contradictory
  stories
- must not leak true implementation meaning

Pros:

- local and deterministic
- no network dependency
- easier to test and cache

Cons:

- limited creativity
- requires dictionary maintenance
- may become formulaic over time

## Strategy B: AI-Assisted Misleading Rename

Use an LLM to generate plausible but incorrect names from a structural summary.

Possible approach:

1. collect structural metadata for classes and members
2. send only the allowed level of context to a model
3. receive candidate misleading names
4. validate and apply only safe names
5. cache the accepted result for reproducibility

Possible context modes:

- anonymous mode: only structural metadata
- full mode: richer context with higher leakage risk

Pros:

- more varied and creative naming
- better chance of forming a coherent fake narrative
- adaptable to unusual code shapes

Cons:

- possible metadata exposure
- non-determinism unless cached carefully
- cost and provider dependency
- risk of generating names too close to the truth

## Hard Safety Requirements

Every candidate name must pass validation before apply:

- legal Dart identifier for the target context
- not a reserved keyword
- obeys private/public naming rules
- no collisions after full inheritance and library-namespace analysis
- does not violate override-family constraints
- does not look too semantically close to the original name

If a candidate fails validation:

- fall back to a safer strategy by default
- optionally fail in strict mode

## Policy Guardrails

- misleading names may imply synthetic surface semantics
- misleading names must not reveal actual implementation intent
- remote providers should be opt-in only
- any remote-context usage should produce a clear warning
- cached mappings must be versioned and tied to structural fingerprints

## Dependencies

This feature depends on earlier rename maturity:

- trustworthy rename correctness
- mapping and seed policy
- deterministic stable keys for declarations
- keep-name and exclusion controls
- clear validation pipeline for rename output

## Acceptance Criteria

- misleading-name strategy is separated from baseline rename behavior
- deterministic dictionary mode is possible without network access
- AI mode is optional and protected by validation and caching
- invalid or unsafe names never break the build silently

## Test Plan

- validation tests for illegal identifiers and collisions
- deterministic tests for dictionary mode under fixed seed
- fallback tests for invalid AI output
- policy tests ensuring accepted names are not too semantically close to the
  originals

## Open Questions

- should dictionary mode land before any AI mode?
- what is the best policy for measuring semantic similarity to original names?
- how much cross-class narrative coherence is worth the added complexity?
- should AI-assisted rename ever be more than an explicitly experimental mode?

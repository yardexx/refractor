---
title: Passes
description: The pass framework and the concrete passes.
layout: docs
---

# Passes

A **pass** is one unit of obfuscation. The public contract is tiny:

```dart
abstract class Pass {
  String get name;                        // logging / metrics key
  Future<PassResult> run(Component);      // mutates the kernel AST in place
}
```

Nine passes ship today, in three groups — naming & data, expressions, and
control flow (listed at the bottom of this page).

## The five stages

Inside `run()`, every pass follows the same fixed pipeline. Each stage is a
small, type-parameterized interface:

```
select → plan → transform → validate → report
```

| Stage | Interface | Responsibility |
|---|---|---|
| **Selection** | `PassSelector<S>` — `S select(Component)` | Walk the AST, gather eligible nodes into an immutable `S`. No mutation. |
| **Planning** | `PassPlanner<S,P>` — `Future<P> plan(Component, S)` | Turn the selection into exact decisions (`P`). Still no mutation. This is where the *smart* domain reasoning lives. |
| **Transformation** | `PassTransformer<P,O>` — `Future<O> apply(Component, P)` | The only stage that mutates the AST. Returns counts + an artifact (`O`). |
| **Validation** | `PassValidator<P,O>` — `validate(Component, {plan, output})` | Assert post-conditions; throw on violation. (rename uses it; most passes leave it at the no-op default.) |
| **Reporting** | `PassReport` + `PassArtifact` | Human/CI metrics + durable machine-readable output. |

The base marker types (`PassSelection`, `PassPlan`, `PassTransformOutput`) are
essentially empty. The value isn't in the base classes — it's the **uniform
shape**: every pass reads the same way, and `S → P → O` are threaded with
compile-time checking.

<Info>
**Why split plan from transform?** Planning is pure and inspectable — decisions
can be validated and serialized (the symbol map, the encryption records) before
anything is touched. Transformation is the single, auditable mutation point.
</Info>

## How a pass is constructed and run

A pass isn't hardcoded; it's registered via a descriptor and assembled by the
registry:

```dart
abstract interface class PassDefinition<C extends PassConfig> {
  String get name;
  Set<KeepSource> get keepSources;        // which keep mechanisms it honors
  C parseConfig(Map<String, dynamic> json);
  Pass createPass({required C config, required ObfuscationScope scope});
  bool supports(PassConfig config);
}
```

- **`PassRegistry`** — `parseAll(yaml)` turns config into typed `PassConfig`s.
  `createAll(...)` builds **one** shared `KeepResolver`, then for each enabled
  pass resolves a `KeepPolicy` (from that pass's `keepSources` + its excludes)
  and hands the pass an `ObfuscationScope`. See [Policy](/architecture/policy).
- **`PassRunner`** — runs the list in order, folds each result into
  `PassResults`, and **continues past failures** (collecting all of them). The
  engine then skips output generation if any pass failed.

```dart
sealed class PassResult
  ├─ PassSucceeded { PassReport report; PassArtifact? artifact; }
  └─ PassFailed    { PassReport report; Exception error; }
```

- **`PassReport`** — metrics/metadata for humans and CI summaries (e.g.
  `classes`/`members`/`variables`, `strings_encrypted`). Ephemeral.
- **`PassArtifact`** — durable, machine-readable output written to
  `build_artifacts.json` (the rename symbol map, the string-encryption records).

<Info>
The `PassReport` metadata keys and the artifact shapes are a **contract**: the
spectrometer test harness (`packages/spectrometer`) and the CLI reporters
depend on them. Keep them stable.
</Info>

## The shape of a concrete `run()`

```dart
Future<PassResult> run(Component component) async {
  try {
    final selection = Selector(scope: scope).select(component);
    final plan      = await Planner(...).plan(component, selection);
    final output    = await Transformer(scope: scope).apply(component, plan);
    Validator().validate(component, plan: plan, output: output);   // rename only
    return PassSucceeded(artifact: output.artifact, report: PassReport(...));
  } on Object catch (e) {
    return PassFailed(error: ..., report: PassReport(name, message: '$e'));
  }
}
```

The mutation stage extends `ScopedKernelTransformer` (in the toolkit), which
gates traversal on the pass's scope and tracks const/annotation context.

## The passes

Nine passes ship today. This page is about the framework they share; for what
each one actually does — its guarantees, config, and limits — see the
[Rulebook](/rulebook).

**Naming & data**

- **[Rename](/rulebook/rename)** — renames classes, members, and variables.
- **[String encryption](/rulebook/string-encryption)** — replaces string literals with an injected runtime decoder.
- **[Integer encryption](/rulebook/int-encryption)** — replaces integer literals with an injected runtime decoder.

**Expressions**

- **[Arithmetic mangling](/rulebook/arithmetic-mangling)** — rewrites `+`/`*` into equivalent, uglier expressions.

**Control flow**

- **[Opaque predicates](/rulebook/opaque-predicates)** — entangles branch conditions with always-true predicates.
- **[Control-flow flattening](/rulebook/control-flow-flatten)** — turns a straight-line body into a switch state machine.
- **[Dead code](/rulebook/dead-code)** — inserts never-executed, opaquely-guarded junk.
- **[Bogus control flow](/rulebook/bogus-control-flow)** — wraps a body in an always-true branch over a real-looking clone.
- **[Call indirection](/rulebook/call-indirection)** — routes static calls through a never-inline forwarder.

They all build on the shared kernel operations described in
[kernel_toolkit](/architecture/kernel-toolkit).

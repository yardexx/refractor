---
title: Passes
description: How a pass is built, created and run.
layout: docs
---

A pass is one kind of obfuscation, such as renaming, string encryption or
control-flow flattening. From the outside it is a very small interface: a name
for logs and metrics, and a method that rewrites the program.

```dart
abstract class Pass {
  String get name;                        // logging / metrics key
  Future<PassResult> run(Component);      // mutates the kernel AST in place
}
```

Nine passes ship today. They are listed at the bottom of this page, and the
[Rulebook](/rulebook) describes what each one does to your code.

## Five stages inside every pass

Every pass does its work in the same five steps, and each step is its own small
interface. Select and plan only read the program. Transform is the one step that
changes it.

<StagesDiagram />

| Stage | Interface | What it does |
|---|---|---|
| Select | `PassSelector<S>`: `S select(Component)` | Walks the AST and collects the nodes the pass may change, without changing anything. |
| Plan | `PassPlanner<S,P>`: `Future<P> plan(Component, S)` | Decides exactly what to do with each node. Most of a pass's real logic lives here. |
| Transform | `PassTransformer<P,O>`: `Future<O> apply(Component, P)` | Applies the plan to the AST and returns counts and an artifact. |
| Validate | `PassValidator<P,O>`: `validate(Component, {plan, output})` | Checks the result and throws if something is wrong. Only rename uses it so far. |
| Report | `PassReport` and `PassArtifact` | Metrics for people and CI, plus machine-readable output for tools. |

The base types (`PassSelection`, `PassPlan`, `PassTransformOutput`) are nearly
empty. What they buy is consistency: every pass reads the same way, and the
compiler checks that each stage's output type matches the next stage's input.

<Info>

Planning is kept apart from transforming so that decisions can be checked and
saved before anything changes. The symbol map and the string-encryption records
both come out of the plan, which leaves the transform step as the only place the
AST is modified.

</Info>

## How passes are created and run

Passes aren't hardcoded. Each one registers a definition that knows its name, how
to read its config, which keep rules it follows, and how to build the pass:

```dart
abstract interface class PassDefinition<C extends PassConfig> {
  String get name;
  Set<KeepSource> get keepSources;        // which keep mechanisms it honors
  C parseConfig(Map<String, dynamic> json);
  Pass createPass({required C config, required ObfuscationScope scope});
  bool supports(PassConfig config);
}
```

`PassRegistry` reads the `passes` section of `refractor.yaml` into typed configs.
When a build starts, `createAll(...)` builds one shared `KeepResolver`, works out
each enabled pass's keep policy from its keep sources and excludes, and hands
every pass its own `ObfuscationScope` (see [Policy](/architecture/policy)).

`PassRunner` then runs the passes in order. It doesn't stop at the first failure.
It collects every result so the report can show all the problems at once, and the
engine skips writing output if any pass failed. Each result is one of two types:

```dart
sealed class PassResult
  ├─ PassSucceeded { PassReport report; PassArtifact? artifact; }
  └─ PassFailed    { PassReport report; Exception error; }
```

`PassReport` holds the metrics and messages you see in the build report and the
GitHub job summary, such as `classes`, `members` and `strings_encrypted`. It
isn't saved anywhere. `PassArtifact` is the part that lasts: it is written to
`build_artifacts.json`, and holds things like the rename symbol map and the
string-encryption records.

<Info>

The end-to-end test harness and the CLI reporters read the report keys and the
artifact formats, so renaming or reshaping them is a breaking change.

</Info>

## What a `run()` looks like

Put together, a typical `run()` is the five stages in order, wrapped so that any
error becomes a `PassFailed`:

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

The transform stage builds on `ScopedKernelTransformer` from the toolkit. It
skips libraries outside the pass's scope and keeps track of when it is inside a
`const` expression or an annotation, where code can't be rewritten.

## The nine passes

Each card links to the pass's Rulebook page, with its options, guarantees and an
example.

<PassGrid />

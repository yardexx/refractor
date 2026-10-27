---
title: Call indirection
description: Routes direct static calls through an injected never-inline forwarder.
layout: docs
---

<PassFacts pass="call" />

## What it does

Routes direct static calls through an injected forwarder, so the direct call
edge no longer appears in the binary's static call graph. `f(a, b)` becomes
`refractorCall(f, [a, b]) as R`, where `refractorCall` is a
`@pragma('vm:never-inline')` helper that dispatches via `Function.apply`. The
never-inline boundary stops the AOT compiler from folding the indirection away.

## Example

`sum` and `withTax` are top-level functions called with positional arguments, so both calls go through the forwarder; `as double` restores the static type.

<PassCompare pass="call">

```dart
double total(List<double> items) {
  final net = sum(items);
  return withTax(net);
}
```

```dart
double total(List<double> items) {
  final net = refractorCall(
      sum, [items]) as double;
  return refractorCall(
      withTax, [net]) as double;
}
```

</PassCompare>

## What it targets

Direct static calls in **project** code where the target is itself in scope
(project code, not kept, not SDK). To keep the `Function.apply` forwarding exact,
it only routes calls that are:

- to a **non-generic static method** (a top-level or `static` function);
- with **positional-only** arguments (no named arguments, no type arguments);
- outside any `const` context.

Everything else — generic targets, named/typed arguments, calls to the SDK or to
kept code — is left as a direct call.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```
refractor:
  passes:
    call_indirection: true
```

</TabItem>
<TabItem label="All options" value="all">

```
refractor:
  passes:
    call_indirection:
      enabled: true
      exclude: []     # extra library globs
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turn the pass on/off. |
| `exclude` | glob list | `[]` | Extra libraries this pass leaves untouched. |

## Scope & keep

Honors `exclude` globs and `@Refractor.keep()` annotations — a kept call site
keeps its direct call, and calls to a kept target stay direct (the target must be
in scope to be routed). The entry point's name is irrelevant to it. See
[Policy](/architecture/policy).

## Guarantees & limitations

<Guarantees>
<Promises>

- **Behaviour-preserving.** `Function.apply` forwards the exact positional
  arguments; void and `dynamic` results need no cast, others are restored with
  `as R` (the dynamic value always is that type, so the cast never throws).
- **Breaks the static edge.** The call becomes an indirect dynamic dispatch the
  compiler can't devirtualize back, so tools that reconstruct the call graph
  from direct invocations lose the edge.

</Promises>
<Caveats>

- **The target is still named at the site.** This breaks the direct edge and
  forces dynamic dispatch, but the tear-off still references the callee — a
  name-hiding dispatcher (route by id) is a heavier follow-up.
- **Performance tradeoff.** Each routed call becomes a dynamic `Function.apply`
  with a small argument list; exclude hot paths.

</Caveats>
</Guarantees>

## Output

- **Metrics:** `calls_indirected` (count).

<PassPager pass="call" />

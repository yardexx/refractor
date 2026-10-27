---
title: Call indirection
description: Sends static calls through a forwarder so they drop out of the call graph.
layout: docs
---

<PassFacts pass="call" />

## What it does

Call indirection sends direct calls to static functions through a forwarder that
Refractor adds to your program. `f(a, b)` becomes `refractorCall(f, [a, b]) as R`,
and `refractorCall` makes the call with `Function.apply`. Tools that rebuild a
program's call graph from its direct calls lose the link between caller and
callee. The forwarder is marked never-inline, so the compiler can't turn it back
into a direct call.

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

It routes direct calls in your project's code to top-level or `static` functions
that are themselves in your project, aren't generic, and take positional
arguments only. Calls with named or type arguments, calls to the SDK or to kept
code, and calls in `const` contexts stay direct, so the forwarding is always
exact.

It follows `exclude` globs and `@Refractor.keep()`, like every pass.

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    call_indirection: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
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
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change. `Function.apply` passes the exact positional arguments, and the `as R` cast restores the result's type. It can't fail, because the value always has that type. Calls that return `void` or `dynamic` need no cast.
- The call becomes an indirect, dynamic one that the compiler can't turn back into a direct call, so the edge disappears from the static call graph.

</Promises>
<Caveats>

- The function is still named at the call site, because the tear-off refers to it. Hiding the name as well would take a dispatcher that routes by id, which is a bigger change.
- Each routed call goes through `Function.apply`, which costs time, so exclude hot code.

</Caveats>
</Guarantees>

## Output

The build report counts `calls_indirected`.

<PassPager pass="call" />

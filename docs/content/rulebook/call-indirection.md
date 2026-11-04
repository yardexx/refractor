---
title: Call indirection
description: Sends static calls through a forwarder so they drop out of the call graph.
layout: docs
---

<PassFacts pass="call" />

## What it does

Tools that rebuild a program's call graph follow its direct calls: this
function calls that one. This pass sends direct calls to static functions
through a forwarder that Refractor adds to your program. `f(a, b)` becomes
`refractorCall(f, [a, b]) as R`, and `refractorCall` makes the call with
`Function.apply`, so the direct edge from caller to callee is gone.

<PassAnimation pass="call" />

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

## What it changes

- Calls in your project's code to top-level or `static` functions in your
  project, with positional arguments only, including optional ones and calls
  with no arguments, in sync and `async` code alike.

## What it leaves alone

- Calls with named or type arguments, and calls to generic functions.
- Instance methods, constructors and factories.
- Calls to the SDK or to kept code, and calls in `const` contexts.
- Calls through a variable that holds a function.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    call_indirection: true
```

It has no options of its own. `enabled` and `exclude` work as on every pass;
see [Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** High per call. In a native executable on an Apple-silicon Mac, a
routed call took about 180 nanoseconds against under 2 for a direct one,
because `Function.apply` builds an argument list and dispatches dynamically.
Keep it out of hot code with `exclude`.

**Strength.** The direct edges are gone from the call graph, but the callee is
still named at the call site, through the reference passed to the forwarder.
On its own, that reference also keeps the function's name in the executable,
where the native compiler would otherwise strip it. Turn
[rename](/rulebook/rename) on as well: it renames routed functions like any
other, and their names no longer reach the binary.

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change. `Function.apply` passes the exact positional arguments, and the `as R` cast restores the result's type. Calls that return `void` need no cast.
- The forwarder is marked never-inline, so the compiler can't turn the call back into a direct one.

</Promises>
<Caveats>

- Without rename, routed function names stay visible in the binary.
- Each routed call costs about a hundred times a direct one.

</Caveats>
</Guarantees>

## Works with

- **Rename.** Use them together, in either order: routed functions get short
  names, and their original names don't reach the binary.
- **String and integer encryption.** Listed before this pass, their decoder
  calls are routed as well. That hides the decoders from the call graph, but
  adds the forwarder's cost to every decode: about 250 nanoseconds per number
  in a test. Passes run in the order they're listed.
- **Control-flow flattening** works in either order.

<PassPager pass="call" />

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
Worse for now: those references keep function names in the executable that the
native compiler would otherwise strip, so `strings` finds names it didn't find
before, and [rename](/rulebook/rename) can't currently hide them (see below).

## Guarantees & limitations

<Guarantees>
<Promises>

- Behaviour doesn't change. `Function.apply` passes the exact positional arguments, and the `as R` cast restores the result's type. Calls that return `void` need no cast.
- The forwarder is marked never-inline, so the compiler can't turn the call back into a direct one.

</Promises>
<Caveats>

- **Known issues, fixes in progress:** listed after [string encryption](/rulebook/string-encryption), routed decoder calls crash at runtime with a type error; and it doesn't combine with rename yet (see below).
- Routed function names stay visible in the binary.
- Each routed call costs about a hundred times a direct one.

</Caveats>
</Guarantees>

## Works with

- **Rename.** Not yet, in either order. Listed before this pass, rename
  renames the forwarder itself, and this pass then silently routes nothing.
  Listed after, rename leaves every routed function with its original name.
- **String encryption.** Listed before this pass, the decoder calls get routed
  too, and they crash at runtime with a type error. List call indirection
  first until that's fixed.
- **Integer encryption.** Listed before this pass, its decoder calls are routed
  as well: that hides them from the call graph, at about 250 nanoseconds per
  decoded number. Passes run in the order they're listed.
- **Control-flow flattening** works in either order.

<PassPager pass="call" />

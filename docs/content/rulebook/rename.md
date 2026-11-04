---
title: Rename
description: Gives your classes, members and variables short, meaningless names.
layout: docs
---

<PassFacts pass="rename" />

## What it does

Names are usually the first thing a reader of a decompiled binary goes by:
`SecretVault.verifyLicenseKey` says what the code is for before anyone reads a
line of it. This pass replaces the names of your classes, methods, fields,
constructors, local variables and parameters with short, meaningless ones, and
updates every place they're used so the program still runs.

<PassAnimation pass="rename" />

## Example

`Gateway` comes from a dependency, so it keeps its name, and so do its `pay` method and the `id` it returns; everything declared in your package is renamed.

<PassCompare pass="rename">

```dart
class Payments {
  final Gateway gateway;
  Payments(this.gateway);

  String charge(String token) {
    final receipt = gateway.pay(token);
    return receipt.id;
  }
}
```

```dart
class a {
  final Gateway b;
  a(this.b);

  String c(String d) {
    final e = b.pay(d);
    return e.id;
  }
}
```

</PassCompare>

## What it changes

- Classes, methods, fields, getters, setters and constructors declared in your
  project's code.
- Local variables and parameters.
- Enum classes and their values, though the value names stay readable (see
  below).

## What it leaves alone

- `main`, so the program keeps its entry point. Rename is the only pass that
  keeps the entry point; see [Policy](/architecture/policy).
- Members that override a type from outside your project, like Flutter's
  `build` or `==`, `hashCode` and `toString`, since renaming them would break
  the override.
- Classes the compiler generates for mixin applications, because other
  generated code relies on their names.
- Named parameters of instance methods that can be called dynamically, where
  not every call site can be found.
- Code kept with `exclude` or `@Refractor.keep()`.

## Configuration

```yaml
refractor:
  passes:
    rename:
      seed: 1337   # optional: fixes the names, for reproducible builds
```

| Option | Type | Default | Meaning |
|---|---|---|---|
| `seed` | int | none | Fixes the generated names, for reproducible builds. |

`enabled` and `exclude` work as on every pass; see
[Configuration](/guide/configuration#pass-options).

## Cost and strength

**Cost.** None at runtime: a hot loop of method calls ran at the same speed with
and without rename, within measurement noise, and the binary came out a few
bytes smaller, since the names are shorter.

**Strength.** Run `strings` on a built executable and your class and method
names are gone; only `main` and overrides such as `toString` keep theirs. Three
things stay readable on purpose or by necessity: your library's URI (for
example `package:app/main.dart`), your string literals, which
[string encryption](/rulebook/string-encryption) covers, and the names of enum
values, because `.name` and `toString()` have to return them.

## Guarantees & limitations

<Guarantees>
<Promises>

- Members that override each other across a class hierarchy are grouped and all get the same new name, so overrides keep working.
- Names it can't rewrite safely, such as some dynamic calls and tear-offs, are put back to their originals rather than risk breaking the program.
- A final check confirms every planned rename happened and no two declarations ended up with the same name. If it fails, the build stops and writes nothing.

</Promises>
<Caveats>

- Code that prints type names sees the new ones: `runtimeType` prints `Y` instead of `AccountRecord`, and the default `toString()` prints `Instance of 'Y'`.
- It can't see code that looks members up by name at runtime, such as `dart:mirrors`. Keep those declarations with `@Refractor.keep()`.
- Named arguments at dynamic call sites keep their names.

</Caveats>
</Guarantees>

## Works with

- **String and integer encryption.** Without rename, their decoders keep their
  names, `refractorDecode` and `refractorDecodeInt`, in the binary, which
  points straight at every encrypted value. With rename on, in either order,
  they're renamed like the rest of your code.
- **Call indirection.** Turn rename on with it, in either order. Rename gives
  the routed functions short names; without it, call indirection keeps their
  original names in the binary.
- **Symbolication.** Every renamed build writes a symbol map, which
  [`refractor symbolicate`](/recipes/symbolication) uses to turn obfuscated
  stack traces back into your names.

## Output

The mapping from new names back to the originals goes into
`build_artifacts.json` and into the [symbol map](/recipes/symbolication). Both
undo the renaming, so archive them privately and keep them out of anything you
ship.

<PassPager pass="rename" />

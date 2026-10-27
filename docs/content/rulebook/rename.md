---
title: Rename
description: Gives your classes, members and variables short, meaningless names.
layout: docs
---

<PassFacts pass="rename" />

## What it does

Rename replaces the names of your classes, methods, fields, constructors, local
variables and parameters with short, meaningless ones, and updates every place
they're used so the program still runs. It does more than any other pass to make
a decompiled binary hard to read, because names are usually the first thing a
reader goes by.

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

## What it targets

It renames classes, members and variables in your project's code, and leaves a
few things alone on purpose:

- classes the compiler generates for mixin applications, because other generated
  code relies on their names;
- members that override a type from outside your project, like Flutter's `build`
  or `==`, `hashCode` and `toString`, since renaming them would break the
  override;
- named parameters of instance methods that can be called dynamically, where not
  every call site can be found.

It follows all three keep rules: `exclude` globs, `@Refractor.keep()`, and the
entry point, so `main` keeps its name. See [Policy](/architecture/policy).

## Configuration

<Tabs defaultValue="minimal">
<TabItem label="Minimal" value="minimal">

```yaml
refractor:
  passes:
    rename: true
```

</TabItem>
<TabItem label="All options" value="all">

```yaml
refractor:
  passes:
    rename:
      enabled: true
      exclude: []     # extra library globs to skip
      # seed: 1337    # optional: fixes the names for
                      # reproducible builds
```

</TabItem>
</Tabs>

| Option | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Turns the pass on or off. |
| `exclude` | glob list | `[]` | More libraries for this pass to skip, on top of the global `exclude`. |
| `seed` | int | none | Fixes the generated names, for reproducible builds. |

## Guarantees & limitations

<Guarantees>
<Promises>

- Members that override each other across a class hierarchy are grouped and all get the same new name, so overrides keep working.
- Names it can't rewrite safely, such as some dynamic calls and tear-offs, are put back to their originals rather than risk breaking the program.
- A final check confirms every planned rename happened and no two declarations ended up with the same name. If it fails, the build stops and writes nothing.

</Promises>
<Caveats>

- It can't see code that looks members up by name at runtime, such as `dart:mirrors`. Keep those declarations with `@Refractor.keep()`.
- Named arguments at dynamic call sites keep their names.

</Caveats>
</Guarantees>

## Output

The build report counts the renamed `classes`, `members` and `variables`. The
mapping from new names back to the originals goes into `build_artifacts.json` and
into the [symbol map](/recipes/symbolication), which turns obfuscated stack traces
back into readable ones.

<PassPager pass="rename" />

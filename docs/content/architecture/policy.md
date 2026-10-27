---
title: Policy
description: How Refractor decides what each pass is allowed to change.
layout: docs
---

Before a pass changes anything, it asks one question: may I obfuscate this?
Refractor answers it by asking two smaller questions and combining them. Is this
code part of your project? And has anyone asked to keep it as it is? A
declaration is obfuscated only when the first answer is yes and the second is no.

The two questions are handled by separate pieces of code, `ProjectScope` and
`KeepPolicy`, because they change for different reasons. Which libraries are
yours depends on your package layout; what to keep depends on your config and
annotations. Try a few cases:

<PolicyExplorer />

## Is this my code?

`ProjectScope` works out whether a library belongs to your project or comes from a
dependency or the SDK. It only looks at where the library lives, never at your
config.

A `package:` URI counts as yours when its package name matches the `name` in your
`pubspec.yaml`, and it maps to a path under `lib/`. A `file:` URI counts as yours
when the file sits under the project root. Everything under `dart:` and every
other package is external and never touched.

The answer is cached per library, because it gets asked for almost every node a
pass looks at. `containsLibrary(lib)` gives the yes or no, and
`workspacePathForLibrary(lib)` returns the library's path inside your project, or
`null` for external code.

## Did you ask to keep it?

`KeepPolicy` is the set of declarations to leave alone, and it knows nothing about
which code is yours. Keeping is inherited downward: a kept library keeps all its
classes and members, and a kept class keeps all its members.

There are three ways to keep something, and they form a fixed list:

```dart
enum KeepSource { excludes, annotations, entryPoint }
```

`excludes` are glob patterns: the global `refractor.exclude` list plus any
`exclude` list under a single pass. They keep whole libraries by path.
`annotations` covers `@Refractor.keep()` on a class or member. `entryPoint` is
your program's `main`.

Each pass declares which of these it follows. Every pass honors excludes and
annotations; only rename also keeps the entry point:

| Pass | Follows | Why |
|---|---|---|
| `rename` | excludes, annotations, entry point | It changes names, so `main` has to keep its name to stay the entry point. |
| the other eight | excludes, annotations | They change bodies and literals, not names. Keeping `main`'s name says nothing about the strings or arithmetic inside it. |

`KeepResolver.resolve(sources, passExcludeGlobs)` builds a pass's keep policy from
only the sources that pass declares. It has one branch per source and never
checks which pass is asking, so a new pass only has to declare its sources. It
also only ever scans project libraries; whether external code is in scope is
`ProjectScope`'s question, not this one.

## One answer for every pass

`ObfuscationScope` puts the two halves together, and it is the only thing a pass
consults:

```dart
bool shouldObfuscateLibrary(Library l) => project.containsLibrary(l) && !keep.isLibraryKept(l);
bool shouldObfuscateClass(Class c)     => project.containsLibrary(c.enclosingLibrary) && !keep.isClassKept(c);
bool shouldObfuscateMember(Member m)   => project.containsLibrary(m.enclosingLibrary) && !keep.isMemberKept(m);
```

Passes never repeat the "in the project and not kept" check themselves. The two
halves are still reachable on their own for the rare case that needs them, such
as rename spotting that a class extends a type from a dependency.

`PassRegistry.createAll` builds one `KeepResolver` for the whole build. For each
enabled pass it resolves that pass's keep policy and wraps it, together with the
shared `ProjectScope`, in an `ObfuscationScope`. Every pass gets its own scope, and
the scopes differ only in what they keep.

## What isn't a keep rule

String encryption's `exclude_patterns` option looks similar but works
differently. The patterns match the text of string literals, not declarations, so
they live inside the pass as one of its settings and never reach the policy.

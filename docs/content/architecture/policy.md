---
title: Policy
description: Membership and keep — the one "may I obfuscate this?" oracle.
layout: docs
---

# Policy — membership and keep

Every selector, transformer, and injector asks one question before touching a
node: **"may I obfuscate this?"** That question decomposes into two *orthogonal*
concerns that are easy to conflate. Keeping them separate is the whole design.

<PolicyExplorer />

## Membership — "is this my code?"

`ProjectScope` answers whether a library belongs to the project being obfuscated,
vs. an external package or the SDK. It's purely structural — nothing about user
intent.

- `containsLibrary(lib)` / `workspacePathForLibrary(lib)` → a workspace-relative
  path, or `null` if the library isn't ours.
- Resolution: `package:` URIs must match the pubspec package name → `lib/...`;
  `file:` URIs must sit under the project root; `dart:` and other packages are
  external.
- Memoized per library — membership is queried once per node during
  selection/transformation.

## Keep — "did the user ask to preserve it?"

`KeepPolicy` is the set of declarations to leave alone. Pure keep, no membership.
It has **containment**: a kept library keeps its classes and members; a kept
class keeps its members.

The mechanisms are a fixed, framework-owned vocabulary:

```dart
enum KeepSource { excludes, annotations, entryPoint }
```

- `excludes` — the global `refractor.exclude` globs plus a pass's own `exclude`
  globs. Keeps whole libraries by path.
- `annotations` — `@Refractor.keep()` on classes/members.
- `entryPoint` — the program's `main`.

Each `PassDefinition` declares which sources it honors:

| Pass | Honors | Why |
|---|---|---|
| `rename` | `excludes`, `annotations`, `entryPoint` | It rewrites identifiers, so preserving `main`'s *name* matters. |
| `string_encrypt` | `excludes`, `annotations` | Keeping `main`'s name says nothing about the string literals inside it — those are fine to encrypt. |

## KeepResolver — pass-agnostic

`KeepResolver.resolve(sources, passExcludeGlobs)` builds a `KeepPolicy` from
**only** the declared sources — one branch per source, never branching on pass
identity. That decoupling is why adding a third pass needs no change here: it
just declares its `KeepSource` set. Every scan only ever considers project
libraries — external code is a membership concern, never a keep concern.

## ObfuscationScope — the one oracle

`ObfuscationScope` is the single authority a pass consults. It combines the two
concerns:

```dart
bool shouldObfuscateLibrary(Library l) => project.containsLibrary(l) && !keep.isLibraryKept(l);
bool shouldObfuscateClass(Class c)     => project.containsLibrary(c.enclosingLibrary) && !keep.isClassKept(c);
bool shouldObfuscateMember(Member m)   => project.containsLibrary(m.enclosingLibrary) && !keep.isMemberKept(m);
```

A pass never re-derives "in project and not kept" — it asks the scope. The
`project` and `keep` halves stay accessible for the rare case that must reason
about an *external* node directly (e.g. detecting an external supertype during
rename).

## Who builds it

`PassRegistry.createAll` builds one `KeepResolver` for the whole run, then per
enabled pass resolves that pass's `KeepPolicy` (from its declared `keepSources`)
and constructs an `ObfuscationScope(project, keep)` handed to the pass. So each
pass gets its own scope, differing only in what it keeps.

## Not a keep concern

`string_encrypt`'s literal-exclusion regexes (`exclude_patterns`) are a **pass
parameter** built from config in the pass itself — they filter literal *values*,
not declarations, and never touch the policy layer.

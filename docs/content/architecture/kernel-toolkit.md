---
title: kernel_toolkit
description: The shared kernel-operations layer, and the philosophy behind it.
layout: docs
---

# kernel_toolkit

`lib/src/engine/kernel_toolkit/` is the shared vocabulary passes speak instead of
re-touching raw `package:kernel`. Its goal is authoring ergonomics: writing a new
pass should be mostly *answering domain questions*, not re-learning kernel
internals — and the case-by-case kernel manipulation should live in one audited
place instead of being copy-pasted across passes.

## What it is — and what it is not

It is **not** an abstraction that hides kernel. `Component` stays in the pass and
stage signatures; the toolkit is a set of helpers and thin services *beside*
kernel, not a new layer in the pipeline.

This is a deliberate limit. Kernel-level obfuscation is tractable precisely
*because* the front end hands you resolved types, interface targets, canonical
names, and override relationships. A source-rewriting backend would have none of
that — it's a fundamentally different domain, not a swappable implementation of
the same interface. Trying to abstract over "kernel AST vs source" would either
leak kernel concepts (useless) or be too thin to help. So the toolkit's job is to
tame kernel's irregularity, not to pretend kernel is replaceable.

The "case-by-case" pain of kernel obfuscation is partly **inherent** (Dart's AST
is a zoo: ~40 expression kinds, dispatch in static/instance/dynamic/super/
abstract-super/tear-off/constant forms). No abstraction deletes that; it can only
put it in one place. That's what the toolkit does.

## House style

Every helper is a `static` method on a named, non-instantiable class
(`final class X { const X._(); static ... }`), so call sites read
`MemberModel.nameText(m)` — you always know where a symbol comes from. Stateful
services (`SdkIndex`, `KernelHelperInjector`) and traversal bases/mixins are real
instances/mixins as their nature requires.

## The pieces

```text
kernel_toolkit/
  traversal/
    scoped_transformer.dart   ScopedKernelTransformer  — mutation base (Transformer)
    scoped_visiting.dart      ScopedVisiting           — selector mixin (RecursiveVisitor)
  relations/
    member_model.dart         MemberModel              — name / kind / kindLabel / isInstanceDispatch
    class_relations.dart      ClassRelations           — directSupertypesOf
                              ClassRelationIndex       — transitive super/subtype + override queries
  location/
    enclosing.dart            Enclosing                — member / library / fileUri (parent-walk)
  naming.dart                 KernelNames              — same(Name, Name) (privacy-aware equality)
  sdk/
    sdk_index.dart            SdkIndex                 — require{Library,Class,Procedure,Field,SingleConstructor}, interfaceType
    helper_injector.dart      KernelHelperInjector     — firstEligibleLibrary / freshTopLevelName / addStaticProcedure / pragma
```

Grouped by capability:

- **Traversal** — `ScopedKernelTransformer` (the base for both passes' mutation
  visitors: gates `visitLibrary` on scope, tracks const/annotation depth) and
  `ScopedVisiting` (its read-only analogue for selector `RecursiveVisitor`s).
- **Relations** — `MemberModel` (member-kind classification and dispatch
  predicate) and `ClassRelations`/`ClassRelationIndex` (structural super/subtype
  and override-family queries used by rename's family grouping).
- **Location** — `Enclosing` (the enclosing member/library/fileUri parent-walk).
- **Naming** — `KernelNames.same` (two `Name`s are equal only with matching text
  *and* library — private names differ across libraries).
- **SDK** — `SdkIndex` (resolve SDK types/members by name; a miss throws a
  `CompilationException` with a clear message instead of a bare `StateError`) and
  `KernelHelperInjector` (the mechanics of injecting a static helper into a
  library).

## What stays in the passes

The toolkit owns the *mechanical* knowledge. The **domain reasoning stays in the
passes**: rename's override-family grouping and safety reverts, the symbol-map
assembly (`SymbolMapKey`), and `string_encrypt`'s hand-built decode-function body
(inherently bespoke — the toolkit provides the injection mechanics, not the body).

## How it was built

Extracted incrementally, one behavior-preserving PR at a time, with the e2e /
resistance suite as the guard (it compiles fixtures, runs the binary, and greps
with `strings` to prove no leaks):

1. module skeleton + relocations (`ScopedKernelTransformer`, `ClassRelationIndex`)
2. primitives + dissolve `rename_helpers` (`MemberModel`, `KernelNames`,
   `Enclosing`, `ClassRelations`)
3. `ScopedVisiting` mixin for the selectors
4. `SdkIndex` + `KernelHelperInjector`; refactor the decode injector

## Deferred: MemberReferenceRewriter

The highest-value but highest-risk extraction is left for later: folding rename's
~20 hand-rolled reference-rewriting overrides (`Instance*`/`Super*`/
`AbstractSuper*`/`Dynamic*`, named-argument fixups, canonical-name unbinding) into
a reusable `MemberReferenceRewriter` base under `kernel_toolkit/mutation/`. It's
correctness-critical AST rewriting, so it should land on its own behind a golden
AST/symbol-map diff test.

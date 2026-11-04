---
title: kernel_toolkit
description: The shared helpers the passes use to read and change kernel code.
layout: docs
---

`lib/src/engine/kernel_toolkit/` holds the helpers the passes share for working
with `package:kernel`. The aim is that writing a new pass mostly means answering
questions about the pass itself (what to select, what to change) rather than
relearning the details of the kernel AST. The fiddly kernel handling lives in one
place that has been tested once, instead of being copied from pass to pass.

## Helpers, not a wrapper

The toolkit doesn't hide kernel. `Component` still appears in every pass and stage
signature, and the toolkit sits beside kernel as a set of helpers and small
services rather than as a layer in between.

That is on purpose. Refractor can rename safely because the front end has already
resolved types, call targets and overrides by the time it reads the `.dill`. A
tool that rewrote source code would have none of that, so it isn't another
implementation of the same idea; it is a different problem. An abstraction that
tried to cover both would either leak kernel details anyway or be too thin to
help.

Some of the awkwardness simply comes with the territory. Dart's AST has around
forty kinds of expression, and a call can be static, instance, dynamic, super,
abstract super, a tear-off or a constant. No helper makes that go away. What the
toolkit can do is handle it in one place.

## How the helpers are written

Each helper is a `static` method on a named class that can't be instantiated
(`final class X { const X._(); static ... }`). Call sites therefore read like
`MemberModel.nameText(m)`, and it is always clear where a function comes from.
Things that need state, like `SdkIndex` and `KernelHelperInjector`, are normal
objects, and the traversal bases are a class and a mixin.

## What's in it

```text
kernel_toolkit/
  traversal/
    scoped_transformer.dart   ScopedKernelTransformer   base for the passes' rewriting visitors
    scoped_visiting.dart      ScopedVisiting            read-only mixin for selectors
  relations/
    member_model.dart         MemberModel               a member's name, kind and dispatch style
    class_relations.dart      ClassRelations            a class's direct supertypes
                              ClassRelationIndex        all supertypes, subtypes and overrides
  location/
    enclosing.dart            Enclosing                 the member, library or file around a node
  naming.dart                 KernelNames               name equality that respects privacy
  sdk/
    sdk_index.dart            SdkIndex                  look up SDK classes and members by name
    helper_injector.dart      KernelHelperInjector      add a helper function to a library
```

`ScopedKernelTransformer` is the base class every pass's transform step builds
on. It skips libraries outside the pass's scope and tracks whether it is inside a
`const` expression or an annotation. `ScopedVisiting` does the same scope check
for the read-only visitors the select step uses.

`MemberModel` classifies a member (method, getter, field, constructor) and tells
whether calls to it go through instance dispatch. `ClassRelations` and
`ClassRelationIndex` answer questions about the class hierarchy, which rename
needs to find every member that overrides another and give them all the same new
name.

`Enclosing` walks up from a node to the member, library or file it belongs to.
`KernelNames.same` compares two names properly: private names from different
libraries are different names even when the text matches.

`SdkIndex` finds SDK types and members by name and fails with a clear
`CompilationException` if one is missing, instead of a bare `StateError`.
`KernelHelperInjector` handles the mechanics of adding a static helper, like the
string decoder, to a library.

## What stays in the passes

The toolkit knows how kernel works. Decisions about obfuscation stay in the
passes: rename's grouping of overrides and its fallbacks when a rename can't be
done safely, the assembly of the symbol map, and the body of string encryption's
decoder. The toolkit can inject a function, but what that function does is the
pass's business.

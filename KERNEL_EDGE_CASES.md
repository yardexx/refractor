# Kernel Edge Cases For Refractor

This note is for future LLM/code-review passes working on rename and
string-encrypt behavior in this repo.

It is based on the vendored Kernel sources in
`packages/third_party/kernel/lib/src/ast/*`, not on memory.

## What Matters Most

Refractor bugs have mostly come from 4 Kernel facts:

1. Dynamic call nodes often carry only a textual `Name`, not a target.
2. Metadata lives in `annotations`, and several `transformChildren` methods
   already revisit it.
3. Tear-offs are wrapped by multiple expression node types, not just one.
4. Private names are represented by `Name(text, library)` and scope matters.

If a rename/string-encrypt change touches any of those areas, assume there is
an edge case until a test proves otherwise.

## Member Traversal Facts

Relevant source: `packages/third_party/kernel/lib/src/ast/members.dart`

- `Field.transformChildren(Transformer v)` visits:
  - `type`
  - `annotations`
  - `initializer`
- `Constructor.transformChildren(Transformer v)` visits:
  - `annotations`
  - `initializers`
  - `function`
- `Procedure.transformChildren(Transformer v)` visits:
  - `annotations`
  - `function`
  - optional `signatureType`

Practical consequence:

- If a custom transformer manually walks `annotations` and then calls
  `node.transformChildren(this)`, annotations may be visited twice.
- This matters for string encryption because metadata must stay intact.
- For `Field` and `Constructor`, prefer manual traversal of the non-annotation
  children after guarding `annotations`.

## Invocation Node Facts

Relevant source: `packages/third_party/kernel/lib/src/ast/expressions.dart`

- `DynamicInvocation`
  - has `receiver`, `name`, `arguments`
  - does **not** have `interfaceTarget`
  - dynamic rename logic can only rely on textual selector matching
- `InstanceInvocation`
  - has `receiver`, `name`, `arguments`
  - has `interfaceTarget`
- `StaticInvocation`
  - has a direct static target
- `FunctionInvocation`
  - receiver-based call through `call`
  - no declaration target unless we recover it from the receiver expression
- `LocalFunctionInvocation`
  - points at the local function declaration via `variable.parent`

Practical consequence:

- Dynamic named-argument rewrites are fundamentally unsafe without more target
  knowledge. Preserving named parameters on instance methods is the safe
  default.
- Static/instance/super/local calls can usually rewrite named args directly.
- `FunctionInvocation` requires a wrapper-unwrapping step to recover the target.

## Tear-Off And Wrapper Forms

Relevant source: `packages/third_party/kernel/lib/src/ast/expressions.dart`

Important wrappers for rename:

- `StaticTearOff`
- `InstanceTearOff`
- `ConstructorTearOff`
- `RedirectingFactoryTearOff`
- `FunctionExpression`
- `FunctionTearOff`
- `Instantiation`
- alias wrappers like `VariableGet` and `StaticGet`

Important facts:

- `RedirectingFactoryTearOff` has a `target` `Procedure`.
- `Instantiation` wraps another expression in `expression` plus
  `typeArguments`.
- Generic tear-offs commonly appear as `Instantiation(tearOff, typeArgs)`.

Practical consequence:

- If named-arg rewriting recovers a function target from receiver expressions,
  it must usually unwrap recursively through:
  - `FunctionTearOff`
  - `Instantiation`
  - final/const `VariableGet`
  - final/const `StaticGet`
- Every new supported wrapper needs a regression test.

## Redirecting Factories

Relevant source:
- `packages/third_party/kernel/lib/src/ast/members.dart`
- `packages/third_party/kernel/lib/src/ast/functions.dart`
- `packages/third_party/kernel/lib/src/ast/expressions.dart`

Important facts:

- `Procedure.isRedirectingFactory` is true when
  `function.redirectingFactoryTarget != null`.
- Redirecting factories are still `Procedure`s, not `Constructor`s.
- Tear-offs of redirecting factories use `RedirectingFactoryTearOff`, not
  `ConstructorTearOff`.

Practical consequence:

- Any rename logic that handles constructor tear-offs but not redirecting
  factory tear-offs is incomplete.

## Dynamic Dispatch Rules That Matter

Relevant source:
- `packages/third_party/kernel/lib/src/ast/expressions.dart`
- Refractor code in `lib/src/engine/passes/rename/*`

Important facts:

- `DynamicGet`, `DynamicSet`, and `DynamicInvocation` depend on textual names.
- `DynamicInvocation.transformChildren` does not transform `name`; the name is
  carried as data, not as a reference target.

Practical consequence:

- Renaming unrelated instance members with the same selector can break dynamic
  calls unless they are normalized carefully.
- If any excluded class/library/member still exposes the original selector,
  canonicalizing renamed members to a new shared selector can break receivers
  of the excluded type.
- Safe dynamic normalization must consider excluded siblings too, not only
  renamed members.

## Private Name Facts

Relevant source:
- `packages/third_party/kernel/lib/src/ast/names.dart` via `package:kernel`
- practical behavior visible throughout the AST

Practical facts for Refractor:

- Private names are not just text like `_a`; they are scoped by library.
- Two private names with the same text from different libraries are distinct.

Practical consequence:

- Symbol maps should preserve scoped keys for correctness.
- Compatibility helpers may still need a bare key like `_a`, but only when that
  bare key is unambiguous enough for the intended lookup.
- Reverse lookup helpers should prefer the real emitted symbol (bare key) when
  both scoped and bare compatibility entries exist.

## Counterexample Checklist

When changing rename or string-encrypt code, try these shapes explicitly:

- dynamic call where one matching member is excluded and another is renamed
- dynamic call where the matching type lives in an excluded package library
- final alias to `StaticTearOff`
- final alias to `ConstructorTearOff`
- final alias to `RedirectingFactoryTearOff`
- final alias to `Instantiation(tearOff, typeArgs)`
- final alias to `Instantiation(RedirectingFactoryTearOff(...), typeArgs)`
- mutable alias to a tear-off (should usually stay conservative)
- private symbol map with one scoped entry
- private symbol map with two scoped entries sharing the same original
- private symbol map with two scoped entries with different originals
- field annotation containing a string literal
- constructor annotation containing a string literal

## Working Rule Of Thumb

If a change touches rename/string-encrypt and you cannot answer all 3 of these,
you probably need more tests:

1. Does this node carry a real target, or only a textual name?
2. Does `transformChildren` already traverse the metadata I am about to walk?
3. Can this expression be wrapped in `Instantiation`, tear-offs, or aliases?

# Const-Context Guard In Base Class

**Status:** active
**Owner:** maintainers
**Last reviewed:** 2026-03-23
**Applies to:** `v0.2.0`
**Related:** [../../roadmap/v0.2.0.md](../../roadmap/v0.2.0.md), [01-pass-statistics.md](01-pass-statistics.md), [02-reporters.md](02-reporters.md), [03-github-reporter.md](03-github-reporter.md), [../README.md](../README.md)

## Goal

Move `_constDepth` and `_annotationDepth` tracking from
`StringEncryptTransformer` into `PassTransformer` so all
expression-transforming passes automatically inherit const-context safety.

## Scope

Included:

- shared const-context tracking in base transformer infrastructure
- preservation of current string-encrypt behavior
- regression coverage for const and annotation contexts

Not included:

- adding new expression-transforming passes in this feature

## Acceptance Criteria

- const and annotation tracking lives in the common transformer layer
- string-encrypt behavior remains correct after the refactor
- future expression transforms can reuse the shared guard

## Test Plan

- unit tests for base-class const-context behavior
- regression tests for string-encrypt behavior in const and non-const cases

## Open Questions

- should the base-class tracking remain always-on, or be opt-in later if
  profiling shows measurable cost?

## Current Architecture

**`PassTransformer`** (`lib/src/engine/passes/pass_transformer.dart`):
- Has `ObfuscationTarget` filtering via `visitLibrary`
- Has annotation-skipping helpers: `transformAnnotationList`, `transformClassWithoutAnnotations`, `transformProcedureWithoutAnnotations`, `transformFieldWithoutAnnotations`, `transformConstructorWithoutAnnotations`
- NO const-context tracking

**`StringEncryptTransformer`** (`lib/src/engine/passes/string_encrypt/string_encrypt_transformer.dart`):
- Owns `int _constDepth`, `int _annotationDepth`, `bool _inConstContext`
- Overrides `visitConstantExpression` to increment/decrement `_constDepth`
- Has `_transformAnnotations()` that wraps `transformAnnotationList()` with `_annotationDepth` tracking
- Overrides `visitClass`, `visitProcedure`, `visitField`, `visitConstructor` to call `_transformAnnotations` then delegate to `transformXWithoutAnnotations`

**`RenameTransformer`** (`lib/src/engine/passes/rename/rename_transformer.dart`):
- Extends `PassTransformer`, does NOT need const-context tracking (renaming is safe in const contexts)
- Calls `super.visitClass(node)` etc. directly

---

## Files to Modify

### `lib/src/engine/passes/pass_transformer.dart`

Add const-context tracking fields and getter:

```dart
int _constDepth = 0;
int _annotationDepth = 0;
bool get inConstContext => _constDepth > 0 || _annotationDepth > 0;
```

Override `visitConstantExpression`:

```dart
@override
TreeNode visitConstantExpression(ConstantExpression node) {
  _constDepth++;
  try {
    return super.visitConstantExpression(node);
  } finally {
    _constDepth--;
  }
}
```

Add annotation-tracking method:

```dart
void transformAnnotationsWithTracking(List<Expression> annotations) {
  _annotationDepth++;
  try {
    transformAnnotationList(annotations);
  } finally {
    _annotationDepth--;
  }
}
```

### `lib/src/engine/passes/string_encrypt/string_encrypt_transformer.dart`

Remove all duplicated tracking:
- Delete `_constDepth`, `_annotationDepth`, `_inConstContext`
- Delete `_transformAnnotations()`
- Delete `visitConstantExpression` override
- Replace `_inConstContext` usage with `inConstContext` (from base class)
- Simplify `visitClass`, `visitProcedure`, `visitField`, `visitConstructor` — they only need the `decodeProcedure` skip check:

```dart
@override
TreeNode visitProcedure(Procedure node) {
  if (node == decodeProcedure) return node;
  return super.visitProcedure(node);
}
```

For `visitClass`, `visitField`, `visitConstructor` — if they only existed for `_transformAnnotations`, remove the overrides entirely and let the base class handle them. If base class `visitX` methods don't call `transformAnnotationsWithTracking`, add default overrides in `PassTransformer` that do.

### `lib/src/engine/passes/rename/rename_transformer.dart`

No changes. `RenameTransformer` uses `transformClassWithoutAnnotations` etc. — it doesn't call `transformAnnotationsWithTracking` because rename doesn't transform annotation expressions. The new base class `visitConstantExpression` will track depth during rename traversal but rename never checks `inConstContext`, so it's a no-op.

Verify existing tests pass unchanged.

---

## Design Decisions

**Why a public `inConstContext` getter?**
Subclass transformers check it in their `visitX` methods. Dart has no `protected` keyword — public is the convention. The `_constDepth`/`_annotationDepth` fields stay private.

**Why always-on?**
Tracking cost is two int increments per const expression. Every expression-transforming pass needs it. Always-on prevents bugs where a new pass author forgets to add it.

**Why keep `transformXWithoutAnnotations`?**
`RenameTransformer` uses these to skip annotation processing entirely. Removing them would force rename to traverse annotation trees unnecessarily.

---

## Detailed Tests

- Existing `StringEncryptTransformer` tests must pass unchanged (behavior preserved)
- Add unit test for `PassTransformer.inConstContext`:
  - Transform a component with `ConstantExpression(StringConstant(...))` — verify `inConstContext` is `true` inside
  - Transform a component with a regular `StringLiteral` — verify `inConstContext` is `false`

---

## Detailed Acceptance Criteria

- [ ] `inConstContext` returns `true` inside `ConstantExpression` and annotation lists
- [ ] `inConstContext` returns `false` for regular expression nodes
- [ ] `StringEncryptTransformer` no longer has its own depth tracking
- [ ] All existing tests pass with no behavior changes
- [ ] `RenameTransformer` is unaffected
- [ ] Zero analysis warnings

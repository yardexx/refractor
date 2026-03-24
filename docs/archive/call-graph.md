# Call Graph — Future Feature

## Context

The `RenameScope` will support an optional call graph to capture which members/functions call which others. This is needed for the AI naming generator — it allows the AI to understand code relationships and produce semantically coherent obfuscated names.

## When to Build

When the `AiNameGenerator` is implemented. No current generator uses call graph data.

## Planned Design

```dart
class RenameScope {
  // ... existing fields ...

  /// Optional call graph. Null until AI naming is implemented.
  final CallGraph? callGraph;
}

/// Directed graph of call relationships between members.
class CallGraph {
  /// For each member, the set of members it calls.
  final Map<Member, Set<Member>> callees;

  /// Reverse index: for each member, who calls it.
  Set<Member> callersOf(Member member);
}
```

## Implementation Notes

- Built by a dedicated `CallGraphBuilder` — separate AST walk that tracks `StaticInvocation`, `InstanceInvocation`, `InstanceGet` targets, etc.
- Only tracks calls within user code (filtered by `ObfuscationTarget`).
- Would be a fourth sub-component in `RenameCollector`, run after `DeclarationCollector`.
- Adds a `CallGraphBuilder` to the file layout under `lib/src/engine/passes/rename/`.
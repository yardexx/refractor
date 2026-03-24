# Optimization Resistance: Dart VM CFG Passes

Analysis of the Dart SDK's CFG optimization pipeline and its implications for kernel-level obfuscation.

---

## 1. The Dart VM CFG Pipeline

When the Dart AOT compiler processes a `.dill` file, it builds a control flow graph (CFG) for each function and runs these optimization passes in order:

| # | Pass | What it does |
|---|------|-------------|
| 1 | **SSAComputation** | Converts CFG to SSA form. Assigns unique versions to each variable definition. |
| 2 | **Simplification** | Peephole rewrites: constant folding, algebraic identities, dead phi elimination. |
| 3 | **ValueNumbering** | Eliminates redundant computations by hash-consing expressions (GVN). |
| 4 | **ConstantPropagation** | Propagates known constant values through the graph. Replaces uses with literals. |
| 5 | **ControlFlowOptimizations** | Eliminates unreachable blocks, simplifies branches with known-constant conditions, collapses empty blocks. |
| 6 | **FlowGraphChecker** | Debug-only verification pass. No transformations. |

---

## 2. Threat Assessment

### High threat (actively defeats obfuscation)

- **ConstantPropagation + ControlFlowOptimizations**: This pair eliminates any branch whose condition can be resolved to a constant. If the predicate is a compile-time constant OR can be proven constant through propagation, the dead branch is removed entirely from the compiled output.

- **Simplification**: Folds arithmetic on constants. `(42 ^ 0xCAFE) ^ 0xCAFE` is reduced back to `42` if both operands are `IntLiteral`. Also applies algebraic identities like `x ^ 0 = x`, `x + 0 = x`.

- **ValueNumbering**: If two expressions compute the same value (same operator, same inputs), GVN replaces the second with a reference to the first. This can undo duplicated expressions used for noise.

### Low threat (does not affect obfuscation)

- **SSAComputation**: Structural transformation for the optimizer's benefit. Does not remove or simplify user-visible constructs.

- **FlowGraphChecker**: Verification only. No code transformation.

---

## 3. Pass Viability Matrix

How each obfuscation technique survives each optimizer pass:

| Obfuscation | SSA | Simplification | GVN | ConstProp | CFG Opts | Verdict |
|------------|-----|---------------|-----|-----------|----------|---------|
| **Rename** (identifiers) | Safe | Safe | Safe | Safe | Safe | **Tier 1 — always survives** |
| **String encrypt** (runtime decode) | Safe | Safe | Safe | Safe | Safe | **Tier 1 — always survives** (decode is a function call, not foldable) |
| **Dead code** (`if (false) {...}`) | Safe | Folded | -- | Eliminated | Removed | **Dead — fully eliminated** |
| **Dead code** (`identical([], [])`) | Safe | Safe | Safe | **Eliminated** | **Removed** | **Dead — eliminated** (see section 4) |
| **CFF** (state machine) | Safe | Safe | Safe | Safe* | Safe* | **Tier 1** (state var is runtime-mutable, not constant) |
| **MBA** (depth 1-2) | Safe | Partial | Partial | Safe | Safe | **Tier 2** — survives at depth 1-2; deeper nesting may be partially simplified |
| **Method outlining** | Safe | Safe | Safe | Safe | Safe | **Tier 1** with `@pragma('vm:never-inline')` |
| **Integer encoding** (`n^k^k`) | Safe | **Folded** | -- | **Folded** | -- | **Dead** if both operands are literals |
| **Integer encoding** (runtime key) | Safe | Safe | Safe | Safe | Safe | **Tier 1** with runtime key variable |

*CFF survives because the state variable is written in multiple branches — ConstantPropagation cannot resolve it to a single value.

---

## 4. Why Dead Code Was Removed

### The `identical([], [])` predicate

The dead_code pass used `identical([], [])` as an "opaque" predicate — two fresh list allocations should never be identical, so the condition is always `false`. The hypothesis was that the optimizer cannot prove this statically.

**This hypothesis is wrong.** Here's why:

1. **ConstantPropagation** recognizes `identical()` as a known built-in and can evaluate it when arguments are analyzable allocation expressions.

2. **ControlFlowOptimizations** sees the branch condition resolved to `false` and eliminates the entire `then` block.

3. The dead branch body (`var _d = 0; _d = _d + 1;`) has **no observable side effects** — no writes to external state, no function calls, no I/O. Even if the predicate somehow survived, the optimizer can prove the body is dead via side-effect analysis.

### The fundamental problem

**Any dead code branch that contains no observable side effects will be eliminated**, regardless of predicate complexity. The Dart VM optimizer does not need to resolve the predicate — it can prove the branch body is removable independently. This makes the entire dead_code pass approach unsalvageable without injecting real side effects, which would impact performance.

### What survives instead

For control flow obfuscation, use techniques where **both branches contain observable side effects**:

- **Control flow flattening**: All switch cases contain real code. The dispatcher is a runtime variable, not a constant predicate.
- **Bogus control flow with cloned code**: Both branches execute real code; only one path is taken at runtime, but the optimizer cannot prove which one without solving the predicate.
- **Method outlining**: Extracted procedures are real calls that the optimizer cannot remove.

---

## 5. Design Rules for Optimization-Resistant Obfuscation

### Rule 1: Never produce all-constant expressions

If every operand in an expression is a compile-time constant, the Simplification pass will fold it:

```
// BAD: folded to 42
IntLiteral(0xCA94) ^ IntLiteral(0xCAFE)

// GOOD: cannot be folded (variable read)
VariableGet(key) ^ IntLiteral(0xCAFE)
```

Always include at least one runtime-derived operand (variable read, function call, field access).

### Rule 2: Use `@pragma('vm:never-inline')` on injected procedures

The AOT compiler inlines small procedures. If an injected decode/helper function is inlined into its caller, the obfuscation structure is lost:

```dart
@pragma('vm:never-inline')
String _obfDecode$(List<int> bytes, int key) => ...
```

This prevents the AOT compiler from inlining, preserving the indirection.

### Rule 3: Structural transforms are inherently safe

Rename, outlining, and string indirection change the *structure* of the program — they don't insert expressions that can be simplified away. These are Tier 1 techniques that always survive the optimizer pipeline.

### Rule 4: Both branches must be live

For control flow obfuscation, ensure both paths of any conditional contain code with observable side effects. If one path is provably dead (no side effects), the optimizer removes it.

### Rule 5: Runtime state defeats constant propagation

Variables written from multiple control flow paths cannot be resolved by ConstantPropagation. CFF's state variable is the canonical example — it's assigned different values in each switch case, so the optimizer treats it as non-constant.

---

## 6. Implications for v0.2

| Proposed feature | Viability | Notes |
|-----------------|-----------|-------|
| **CFF** | Viable | State variable is runtime-mutable. Use `@pragma('vm:never-inline')` on dispatcher if extracted. |
| **MBA** (depth 1-2) | Viable | Keep depth low. Avoid all-constant operands. |
| **Dead code / bogus control flow** | Weak | Demote to P4. Only viable with cloned real code in both branches + strong opaque predicates. |
| **Method outlining** | Viable | With `@pragma('vm:never-inline')`. |
| **Integer encoding** | Weak | Only viable with runtime key laundering (adds real cost). |
| **Rename improvements** | Viable | Structural — always survives. |
| **String encrypt improvements** | Viable | Runtime decode calls — always survives. |

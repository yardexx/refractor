import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';

/// Builds an always-true boolean expression from a per-site constant [k].
///
/// This is the ProGuard-style rule element: a pattern (any boolean condition)
/// maps to a *set* of these templates, and the planner picks one per site at
/// random, so no two strengthened conditions look alike.
typedef OpaquePredicateTemplate = Expression Function(KernelBuilder b, int k);

/// The rule table of constant opaque-true templates. Each identity holds for
/// every `k >= 1`, and the planner only ever supplies such a `k`. These inline
/// a constant, so a constant-folding decompiler can discharge them; the planner
/// prefers the live templates below where an in-scope variable is available.
const List<OpaquePredicateTemplate> opaquePredicateTemplates = [
  _squareIsNonNegative,
  _squarePlusKIsPositive,
  _squareIsAtLeastK,
];

/// Builds an always-true boolean from fresh reads of an in-scope int variable.
typedef OpaquePredicateLiveTemplate =
    Expression Function(KernelBuilder b, Expression Function() ref);

/// The rule table of live opaque-true templates — data-dependent on a runtime
/// variable, so they cannot be folded to a constant `true`.
const List<OpaquePredicateLiveTemplate> opaquePredicateLiveTemplates = [
  _maskedSquareIsNonNegative,
];

/// `k * k >= 0`.
Expression _squareIsNonNegative(KernelBuilder b, int k) =>
    b.ge(b.mul(b.intLit(k), b.intLit(k)), b.intLit(0));

/// `k * k + k > 0` (true for every `k >= 1`).
Expression _squarePlusKIsPositive(KernelBuilder b, int k) => b.gt(
  b.add(b.mul(b.intLit(k), b.intLit(k)), b.intLit(k)),
  b.intLit(0),
);

/// `k * k >= k` (true for every `k >= 1`).
Expression _squareIsAtLeastK(KernelBuilder b, int k) =>
    b.ge(b.mul(b.intLit(k), b.intLit(k)), b.intLit(k));

/// `(v & 0xFFFF) * (v & 0xFFFF) >= 0`. The mask bounds the value to
/// `[0, 65535]`, whose square never overflows and is never negative, so this is
/// always true for any `v` — yet it reads a live variable, so it cannot be
/// folded to a constant.
Expression _maskedSquareIsNonNegative(
  KernelBuilder b,
  Expression Function() ref,
) {
  final low1 = b.bitAnd(ref(), b.intLit(0xFFFF));
  final low2 = b.bitAnd(ref(), b.intLit(0xFFFF));
  return b.ge(b.mul(low1, low2), b.intLit(0));
}

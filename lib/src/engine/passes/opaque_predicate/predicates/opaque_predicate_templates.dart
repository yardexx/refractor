import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/builder/kernel_builder.dart';

/// Builds an always-true boolean expression from a per-site constant [k].
///
/// This is the ProGuard-style rule element: a pattern (any boolean condition)
/// maps to a *set* of these templates, and the planner picks one per site at
/// random, so no two strengthened conditions look alike.
typedef OpaquePredicateTemplate = Expression Function(KernelBuilder b, int k);

/// The rule table of opaque-true templates. Each identity holds for every
/// `k >= 1`, and the planner only ever supplies such a `k`.
///
/// The constant is inlined, so a constant-folding decompiler can still
/// discharge these; entangling the predicate with an in-scope variable (so it
/// resists static folding) is a later enhancement that needs scope/liveness
/// analysis.
const List<OpaquePredicateTemplate> opaquePredicateTemplates = [
  _squareIsNonNegative,
  _squarePlusKIsPositive,
  _squareIsAtLeastK,
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

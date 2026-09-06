import 'package:kernel/ast.dart';

/// Identity helpers for kernel [Name]s.
///
/// (`KernelNames`, not `Names` — `package:kernel` already defines a `Names`.)
final class KernelNames {
  const KernelNames._();

  /// Whether [a] and [b] are the same identifier in the same privacy scope.
  ///
  /// Private names are only equal when they share the same library, so text
  /// equality alone is insufficient.
  static bool same(Name a, Name b) =>
      a.text == b.text && identical(a.library, b.library);
}

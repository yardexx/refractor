import 'package:kernel/ast.dart';

/// Named `KernelNames` (not `Names`) — `package:kernel` already defines a
/// `Names`.
final class KernelNames {
  const KernelNames._();

  /// Private names are equal only when they share a library, so text equality
  /// alone is insufficient.
  static bool same(Name a, Name b) =>
      a.text == b.text && identical(a.library, b.library);
}

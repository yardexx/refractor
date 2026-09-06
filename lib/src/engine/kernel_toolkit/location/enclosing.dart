import 'package:kernel/ast.dart';

/// Enclosing-node lookups over the kernel parent chain.
///
/// Replaces the parent-walk that was copy-pasted across selectors and
/// transformers.
final class Enclosing {
  const Enclosing._();

  /// The nearest enclosing [Member] of [node], or null.
  static Member? member(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Member) return current;
      current = current.parent;
    }
    return null;
  }

  /// The nearest enclosing [Library] of [node], or null.
  static Library? library(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Library) return current;
      current = current.parent;
    }
    return null;
  }

  /// The file URI most specific to [node]: its enclosing member's, else its
  /// enclosing library's, else null.
  static Uri? fileUri(TreeNode node) {
    final enclosingMember = member(node);
    if (enclosingMember?.fileUri != null) return enclosingMember!.fileUri;
    return library(node)?.fileUri;
  }
}

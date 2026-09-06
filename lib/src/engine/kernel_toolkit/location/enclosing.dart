import 'package:kernel/ast.dart';

final class Enclosing {
  const Enclosing._();

  static Member? member(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Member) return current;
      current = current.parent;
    }
    return null;
  }

  static Library? library(TreeNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is Library) return current;
      current = current.parent;
    }
    return null;
  }

  static Uri? fileUri(TreeNode node) {
    final enclosingMember = member(node);
    if (enclosingMember?.fileUri != null) return enclosingMember!.fileUri;
    return library(node)?.fileUri;
  }
}

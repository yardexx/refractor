import 'package:kernel_model/src/kernel_node.dart';

/// The root of a parsed kernel tree — one per `.dill` file.
class KernelTree {
  const KernelTree({
    required this.source,
    required this.libraries,
  });

  /// Original file path or label.
  final String source;

  /// Top-level library nodes.
  final List<LibraryNode> libraries;
}

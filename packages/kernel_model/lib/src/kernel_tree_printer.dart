import 'package:kernel_model/src/kernel_node.dart';
import 'package:kernel_model/src/kernel_tree.dart';

/// Renders a [KernelTree] as indented text.
class KernelTreePrinter {
  /// Print a [KernelTree] as a human-readable string.
  String print(KernelTree tree) {
    final buf = StringBuffer();

    for (final lib in tree.libraries) {
      buf.writeln(lib.importUri);
      _writeAnnotations(buf, lib.annotations, indent: '  ');
      _writeChildren(buf, lib.children, indent: '  ');
    }

    return buf.toString().trimRight();
  }

  void _writeChildren(
    StringBuffer buf,
    List<KernelNode> children, {
    required String indent,
  }) {
    for (final child in children) {
      _writeNode(buf, child, indent: indent);
    }
  }

  void _writeNode(
    StringBuffer buf,
    KernelNode node, {
    required String indent,
  }) {
    _writeAnnotations(buf, node.annotations, indent: indent);

    switch (node) {
      case LibraryNode():
        buf.writeln('$indent${node.importUri}');
      case ClassNode():
        buf.writeln('${indent}class ${node.name}');
        _writeChildren(buf, node.children, indent: '$indent  ');
      case ProcedureNode():
        buf.writeln('$indent${node.signature}');
      case FieldNode():
        buf.writeln('$indent${node.label}');
      case ConstructorNode():
        buf.writeln('$indent${node.signature}');
    }
  }

  void _writeAnnotations(
    StringBuffer buf,
    List<String> annotations, {
    required String indent,
  }) {
    for (final annotation in annotations) {
      buf.writeln('$indent$annotation');
    }
  }
}

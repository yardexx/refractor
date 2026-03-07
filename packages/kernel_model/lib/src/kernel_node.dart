/// The kind of a kernel AST node, used for theming and icons.
enum KernelNodeKind {
  library,
  classNode,
  procedure,
  field,
  constructor,
}

/// A single node in a parsed kernel tree.
sealed class KernelNode {
  const KernelNode({
    required this.id,
    required this.label,
    required this.kind,
    this.annotations = const [],
    this.children = const [],
  });

  /// Unique identifier for graph wiring.
  final String id;

  /// Display text for the node.
  final String label;

  /// Node kind for theming / icons.
  final KernelNodeKind kind;

  /// Formatted annotation strings, e.g. `["@pragma('vm:entry-point')"]`.
  final List<String> annotations;

  /// Nested child nodes (classes, procedures, fields, etc.).
  final List<KernelNode> children;
}

/// A library node (top-level container).
class LibraryNode extends KernelNode {
  const LibraryNode({
    required super.id,
    required this.importUri,
    super.annotations,
    super.children,
  }) : super(
         label: '',
         kind: KernelNodeKind.library,
       );

  final Uri importUri;

  @override
  String get label => importUri.toString();
}

/// A class declaration.
class ClassNode extends KernelNode {
  const ClassNode({
    required super.id,
    required this.name,
    required this.isAbstract,
    super.annotations,
    super.children,
  }) : super(label: name, kind: KernelNodeKind.classNode);

  final String name;
  final bool isAbstract;
}

/// A procedure (method / top-level function).
class ProcedureNode extends KernelNode {
  const ProcedureNode({
    required super.id,
    required this.name,
    required this.returnType,
    required this.signature,
    required this.isStatic,
    super.annotations,
  }) : super(
         label: signature,
         kind: KernelNodeKind.procedure,
         children: const [],
       );

  final String name;
  final String returnType;

  /// Full signature, e.g. `"String fetchUser()"`.
  final String signature;

  final bool isStatic;
}

/// A field declaration.
class FieldNode extends KernelNode {
  const FieldNode({
    required super.id,
    required this.name,
    required this.type,
    required this.isFinal,
    required this.isLate,
    super.annotations,
  }) : super(
         label: '',
         kind: KernelNodeKind.field,
         children: const [],
       );

  final String name;
  final String type;
  final bool isFinal;
  final bool isLate;

  @override
  String get label {
    final buf = StringBuffer();
    if (isLate) buf.write('late ');
    if (isFinal) buf.write('final ');
    buf
      ..write(type)
      ..write(' ')
      ..write(name);
    return buf.toString();
  }
}

/// A constructor declaration.
class ConstructorNode extends KernelNode {
  const ConstructorNode({
    required super.id,
    required this.name,
    required this.signature,
    super.annotations,
  }) : super(
         label: signature,
         kind: KernelNodeKind.constructor,
         children: const [],
       );

  final String name;
  final String signature;
}

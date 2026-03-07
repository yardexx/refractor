import 'package:kernel/ast.dart';
import 'package:kernel_model/src/kernel_node.dart';
import 'package:kernel_model/src/kernel_tree.dart';

/// Parses a `package:kernel` [Component] into a [KernelTree].
class KernelParser {
  /// Parse a loaded [Component] into a [KernelTree].
  ///
  /// When [includeSdk] is `false` (default), `dart:*` libraries are skipped.
  KernelTree parse(
    Component component, {
    String source = '',
    bool includeSdk = false,
  }) {
    var nextId = 0;
    String id() => '${nextId++}';

    final libraries = <LibraryNode>[];

    for (final lib in component.libraries) {
      if (!includeSdk && lib.importUri.scheme == 'dart') continue;

      final children = <KernelNode>[];

      for (final proc in lib.procedures) {
        children.add(_parseProcedure(proc, id()));
      }

      for (final field in lib.fields) {
        children.add(_parseField(field, id()));
      }

      for (final cls in lib.classes) {
        children.add(_parseClass(cls, id));
      }

      libraries.add(
        LibraryNode(
          id: id(),
          importUri: lib.importUri,
          annotations: lib.annotations.map(_formatAnnotation).toList(),
          children: children,
        ),
      );
    }

    return KernelTree(source: source, libraries: libraries);
  }

  ClassNode _parseClass(Class cls, String Function() id) {
    final children = <KernelNode>[];

    for (final ctor in cls.constructors) {
      children.add(
        ConstructorNode(
          id: id(),
          name: ctor.name.text,
          signature: '${cls.name}(${_formatParameters(ctor.function)})',
          annotations: ctor.annotations.map(_formatAnnotation).toList(),
        ),
      );
    }

    for (final proc in cls.procedures) {
      children.add(_parseProcedure(proc, id()));
    }

    for (final field in cls.fields) {
      children.add(_parseField(field, id()));
    }

    return ClassNode(
      id: id(),
      name: cls.name,
      isAbstract: cls.isAbstract,
      annotations: cls.annotations.map(_formatAnnotation).toList(),
      children: children,
    );
  }

  ProcedureNode _parseProcedure(Procedure proc, String nodeId) {
    final returnType = _formatType(proc.function.returnType);
    final params = _formatParameters(proc.function);
    return ProcedureNode(
      id: nodeId,
      name: proc.name.text,
      returnType: returnType,
      signature: '$returnType ${proc.name.text}($params)',
      isStatic: proc.isStatic,
      annotations: proc.annotations.map(_formatAnnotation).toList(),
    );
  }

  FieldNode _parseField(Field field, String nodeId) {
    return FieldNode(
      id: nodeId,
      name: field.name.text,
      type: _formatType(field.type),
      isFinal: field.isFinal,
      isLate: field.isLate,
      annotations: field.annotations.map(_formatAnnotation).toList(),
    );
  }

  String _formatParameters(FunctionNode function) {
    final positional = function.positionalParameters
        .map((p) => '${_formatType(p.type)} ${p.name ?? ''}')
        .toList();
    final named = function.namedParameters
        .map((p) {
          final req = p.isRequired ? 'required ' : '';
          return '$req${_formatType(p.type)} ${p.name}';
        })
        .toList();

    final parts = <String>[...positional];
    if (named.isNotEmpty) {
      parts.add('{${named.join(', ')}}');
    }
    return parts.join(', ');
  }

  String _formatType(DartType type) {
    return switch (type) {
      InterfaceType() => type.classNode.name,
      VoidType() => 'void',
      DynamicType() => 'dynamic',
      NeverType() => 'Never',
      FunctionType() => 'Function',
      NullType() => 'Null',
      _ => type.runtimeType.toString(),
    };
  }

  String _formatAnnotation(Expression annotation) {
    return switch (annotation) {
      ConstructorInvocation() => '@${annotation.target.enclosingClass.name}',
      ConstantExpression(constant: final c) => _formatConstantAnnotation(c),
      _ => '@?',
    };
  }

  String _formatConstantAnnotation(Constant constant) {
    return switch (constant) {
      InstanceConstant() => '@${constant.classNode.name}',
      StringConstant() => '@"${constant.value}"',
      _ => '@?',
    };
  }
}

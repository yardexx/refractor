import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';

abstract class PassTransformer extends Transformer {
  PassTransformer({required this.target});

  final ObfuscationTarget target;

  @override
  TreeNode visitLibrary(Library node) {
    if (!target.shouldObfuscateLibrary(node)) return node;
    return super.visitLibrary(node);
  }

  void transformAnnotationList(List<Expression> annotations) {
    for (var i = 0; i < annotations.length; i++) {
      annotations[i] = transform(annotations[i]);
    }
  }

  TreeNode transformClassWithoutAnnotations(Class node) {
    transformList(node.typeParameters, node);
    if (node.supertype != null) {
      node.supertype = visitSupertype(node.supertype!);
    }
    if (node.mixedInType != null) {
      node.mixedInType = visitSupertype(node.mixedInType!);
    }
    transformSupertypeList(node.implementedTypes);
    transformList(node.constructors, node);
    transformList(node.procedures, node);
    transformList(node.fields, node);
    return node;
  }

  TreeNode transformProcedureWithoutAnnotations(Procedure node) {
    node.function = transform(node.function);
    node.function.parent = node;
    if (node.signatureType != null) {
      node.signatureType = visitDartType(node.signatureType!) as FunctionType;
    }
    return node;
  }

  TreeNode transformFieldWithoutAnnotations(Field node) {
    node.type = visitDartType(node.type);
    if (node.initializer != null) {
      node.initializer = transform(node.initializer!);
      node.initializer?.parent = node;
    }
    return node;
  }

  TreeNode transformConstructorWithoutAnnotations(Constructor node) {
    transformList(node.initializers, node);
    node.function = transform(node.function);
    node.function.parent = node;
    return node;
  }
}

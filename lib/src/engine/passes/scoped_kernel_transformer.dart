import 'package:kernel/ast.dart';
import 'package:refractor/src/project/project_scope.dart';

abstract class ScopedKernelTransformer extends Transformer {
  ScopedKernelTransformer({required this.projectScope});

  final ProjectScope projectScope;
  int _constDepth = 0;
  int _annotationDepth = 0;

  bool get inConstContext => _constDepth > 0 || _annotationDepth > 0;

  @override
  TreeNode visitLibrary(Library node) {
    if (!projectScope.containsLibrary(node)) return node;
    return super.visitLibrary(node);
  }

  @override
  TreeNode visitClass(Class node) {
    transformAnnotationList(node.annotations);
    return transformClassWithoutAnnotations(node);
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    transformAnnotationList(node.annotations);
    return transformProcedureWithoutAnnotations(node);
  }

  @override
  TreeNode visitField(Field node) {
    transformAnnotationList(node.annotations);
    return transformFieldWithoutAnnotations(node);
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    transformAnnotationList(node.annotations);
    return transformConstructorWithoutAnnotations(node);
  }

  @override
  TreeNode visitConstantExpression(ConstantExpression node) {
    _constDepth++;
    try {
      return super.visitConstantExpression(node);
    } finally {
      _constDepth--;
    }
  }

  void transformAnnotationList(List<Expression> annotations) {
    _annotationDepth++;
    try {
      for (var i = 0; i < annotations.length; i++) {
        annotations[i] = transform(annotations[i]);
      }
    } finally {
      _annotationDepth--;
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

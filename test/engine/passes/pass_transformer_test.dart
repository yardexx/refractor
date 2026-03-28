import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/passes/scoped_kernel_transformer.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

void main() {
  group('ScopedKernelTransformer', () {
    late Library coreLib;
    late Library userLib;
    late ProjectScope projectScope;

    setUp(() {
      coreLib = makeDartCoreLibrary();
      userLib = makeUserLibrary();
      projectScope = makeProjectScope();
    });

    test('inConstContext is true while visiting constants', () {
      final procedure = Procedure(
        Name('constExample'),
        ProcedureKind.Method,
        FunctionNode(
          Block([
            ReturnStatement(
              ConstantExpression(StringConstant('const_value')),
            ),
          ]),
        ),
        fileUri: userLib.fileUri,
      );
      userLib.addProcedure(procedure);

      final component = makeComponent(coreLib: coreLib, userLib: userLib);
      final transformer = _RecordingTransformer(projectScope: projectScope);

      component.transformChildren(transformer);

      expect(transformer.constContextByConstant['const_value'], isTrue);
    });

    test(
      'inConstContext is true for annotations and false for body literals',
      () {
        final procedure = Procedure(
          Name('annotatedProcedure'),
          ProcedureKind.Method,
          FunctionNode(
            Block([
              ReturnStatement(StringLiteral('body_literal')),
            ]),
          ),
          fileUri: userLib.fileUri,
        )..addAnnotation(StringLiteral('procedure_annotation'));

        final field = Field.mutable(
          Name('flag'),
          fileUri: userLib.fileUri,
        )..addAnnotation(StringLiteral('field_annotation'));

        final constructor = Constructor(
          FunctionNode(EmptyStatement()),
          name: Name(''),
          fileUri: userLib.fileUri,
        )..addAnnotation(StringLiteral('constructor_annotation'));

        final cls = Class(name: 'AnnotatedClass', fileUri: userLib.fileUri)
          ..addAnnotation(StringLiteral('class_annotation'))
          ..addProcedure(procedure)
          ..addField(field)
          ..addConstructor(constructor);
        userLib.addClass(cls);

        final component = makeComponent(coreLib: coreLib, userLib: userLib);
        final transformer = _RecordingTransformer(projectScope: projectScope);

        component.transformChildren(transformer);

        expect(transformer.contextByString['class_annotation'], isTrue);
        expect(transformer.contextByString['procedure_annotation'], isTrue);
        expect(transformer.contextByString['field_annotation'], isTrue);
        expect(transformer.contextByString['constructor_annotation'], isTrue);
        expect(transformer.contextByString['body_literal'], isFalse);
      },
    );
  });
}

final class _RecordingTransformer extends ScopedKernelTransformer {
  _RecordingTransformer({required super.projectScope});

  final Map<String, bool> contextByString = {};
  final Map<String, bool> constContextByConstant = {};

  @override
  Constant visitConstant(Constant node) {
    if (node is StringConstant) {
      constContextByConstant[node.value] = inConstContext;
    }
    return super.visitConstant(node);
  }

  @override
  TreeNode visitStringLiteral(StringLiteral node) {
    contextByString[node.value] = inConstContext;
    return super.visitStringLiteral(node);
  }
}

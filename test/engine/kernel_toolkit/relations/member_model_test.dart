import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/member_model.dart';
import 'package:test/test.dart';

void main() {
  final fileUri = Uri.parse('test:test');

  Procedure procedure(String name, {bool isStatic = false}) => Procedure(
    Name(name),
    ProcedureKind.Method,
    FunctionNode(EmptyStatement()),
    isStatic: isStatic,
    fileUri: fileUri,
  );

  Field field(String name, {bool isStatic = false}) => isStatic
      ? Field.mutable(Name(name), isStatic: true, fileUri: fileUri)
      : Field.mutable(Name(name), fileUri: fileUri);

  Constructor constructor(String name) => Constructor(
    FunctionNode(EmptyStatement()),
    name: Name(name),
    fileUri: fileUri,
  );

  group('MemberModel.nameText', () {
    test('returns the declared name for each member kind', () {
      expect(MemberModel.nameText(procedure('doStuff')), 'doStuff');
      expect(MemberModel.nameText(field('myField')), 'myField');
      expect(MemberModel.nameText(constructor('named')), 'named');
    });
  });

  group('MemberModel.kind', () {
    test('classifies each member kind', () {
      expect(MemberModel.kind(procedure('p')), MemberKind.procedure);
      expect(MemberModel.kind(field('f')), MemberKind.field);
      expect(MemberModel.kind(constructor('c')), MemberKind.constructor);
    });
  });

  group('MemberModel.kindLabel', () {
    test('labels each member kind and null', () {
      expect(MemberModel.kindLabel(procedure('p')), 'procedure');
      expect(MemberModel.kindLabel(field('f')), 'field');
      expect(MemberModel.kindLabel(constructor('c')), 'constructor');
      expect(MemberModel.kindLabel(null), isNull);
    });
  });

  group('MemberModel.isInstanceDispatch', () {
    test('true only for non-static procedures and fields', () {
      expect(MemberModel.isInstanceDispatch(procedure('p')), isTrue);
      expect(MemberModel.isInstanceDispatch(field('f')), isTrue);
      expect(
        MemberModel.isInstanceDispatch(procedure('p', isStatic: true)),
        isFalse,
      );
      expect(
        MemberModel.isInstanceDispatch(field('f', isStatic: true)),
        isFalse,
      );
      expect(MemberModel.isInstanceDispatch(constructor('c')), isFalse);
    });
  });
}

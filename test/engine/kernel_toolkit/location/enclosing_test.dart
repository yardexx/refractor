import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/kernel_toolkit/location/enclosing.dart';
import 'package:test/test.dart';

void main() {
  group('Enclosing', () {
    late Library library;
    late Class cls;
    late Procedure procedure;
    late VariableDeclaration local;

    setUp(() {
      library = Library(
        Uri.parse('package:app/app.dart'),
        fileUri: Uri.parse('file:///app.dart'),
      );
      cls = Class(name: 'C', fileUri: library.fileUri);
      library.addClass(cls);
      local = VariableDeclaration('x');
      procedure = Procedure(
        Name('m'),
        ProcedureKind.Method,
        FunctionNode(Block([local, ReturnStatement()])),
        fileUri: Uri.parse('file:///member.dart'),
      );
      cls.addProcedure(procedure);
    });

    test('member walks up to the nearest enclosing member', () {
      expect(Enclosing.member(local), same(procedure));
      expect(Enclosing.member(cls), isNull);
    });

    test('library walks up to the enclosing library', () {
      expect(Enclosing.library(local), same(library));
      expect(Enclosing.library(cls), same(library));
    });

    test('fileUri prefers the enclosing member, else the library', () {
      expect(Enclosing.fileUri(local), procedure.fileUri);
      expect(Enclosing.fileUri(cls), library.fileUri);
    });
  });
}

import 'dart:io';

import 'package:kernel/kernel.dart';
import 'package:kernel_model/kernel_model.dart';
import 'package:test/test.dart';

void main() {
  group('KernelParser', () {
    late Component component;
    late KernelTree tree;

    setUpAll(() {
      // Compile a fixture to .dill.
      final tmpDir = Directory.systemTemp.createTempSync('kernel_model_test_');
      final sourceFile = File('${tmpDir.path}/main.dart')
        ..writeAsStringSync('''
void main() {
  print('hello');
}

String computeMessage() => 'msg';

class UserService {
  String fetchUser() => 'alice';
  final String _name = 'svc';
}
''');

      final result = Process.runSync('dart', [
        'compile',
        'kernel',
        sourceFile.path,
        '-o',
        '${tmpDir.path}/out.dill',
      ]);
      expect(result.exitCode, equals(0), reason: '${result.stderr}');

      component = loadComponentFromBinary('${tmpDir.path}/out.dill');
    });

    setUp(() {
      tree = KernelParser().parse(component, source: 'test.dill');
    });

    test('source is preserved', () {
      expect(tree.source, equals('test.dill'));
    });

    test('filters SDK libraries by default', () {
      for (final lib in tree.libraries) {
        expect(lib.importUri.scheme, isNot('dart'));
      }
    });

    test('includes SDK libraries when requested', () {
      final withSdk = KernelParser().parse(component, includeSdk: true);
      final schemes = withSdk.libraries.map((l) => l.importUri.scheme).toSet();
      expect(schemes, contains('dart'));
    });

    test('finds user library', () {
      expect(tree.libraries, isNotEmpty);
    });

    test('finds top-level procedures', () {
      final allProcs = tree.libraries
          .expand((l) => l.children)
          .whereType<ProcedureNode>()
          .toList();
      final names = allProcs.map((p) => p.name).toList();
      expect(names, contains('main'));
      expect(names, contains('computeMessage'));
    });

    test('finds class and its members', () {
      final allClasses = tree.libraries
          .expand((l) => l.children)
          .whereType<ClassNode>()
          .toList();
      final userService = allClasses.where((c) => c.name == 'UserService');
      expect(userService, isNotEmpty);

      final cls = userService.first;
      final procNames = cls.children
          .whereType<ProcedureNode>()
          .map((p) => p.name)
          .toList();
      expect(procNames, contains('fetchUser'));

      final fieldNames = cls.children
          .whereType<FieldNode>()
          .map((f) => f.name)
          .toList();
      expect(fieldNames, contains('_name'));
    });

    test('field modifiers are captured', () {
      final fields = tree.libraries
          .expand((l) => l.children)
          .whereType<ClassNode>()
          .where((c) => c.name == 'UserService')
          .expand((c) => c.children)
          .whereType<FieldNode>()
          .toList();
      final nameField = fields.firstWhere((f) => f.name == '_name');
      expect(nameField.isFinal, isTrue);
      expect(nameField.type, equals('String'));
    });

    test('procedure signatures include return type', () {
      final procs = tree.libraries
          .expand((l) => l.children)
          .whereType<ProcedureNode>()
          .toList();
      final compute = procs.firstWhere((p) => p.name == 'computeMessage');
      expect(compute.returnType, equals('String'));
      expect(compute.signature, contains('String'));
      expect(compute.signature, contains('computeMessage'));
    });

    test('every node has a unique id', () {
      final ids = <String>[];
      void collectIds(KernelNode node) {
        ids.add(node.id);
        node.children.forEach(collectIds);
      }
      tree.libraries.forEach(collectIds);
      expect(ids.toSet().length, equals(ids.length));
    });
  });

  group('KernelTreePrinter', () {
    test('produces expected text output', () {
      final tree = KernelTree(
        source: 'test.dill',
        libraries: [
          LibraryNode(
            id: '0',
            importUri: Uri.parse('package:app/main.dart'),
            children: [
              const ProcedureNode(
                id: '1',
                name: 'main',
                returnType: 'void',
                signature: 'void main()',
                isStatic: false,
              ),
              const ClassNode(
                id: '2',
                name: 'Foo',
                isAbstract: false,
                children: [
                  FieldNode(
                    id: '3',
                    name: 'bar',
                    type: 'String',
                    isFinal: true,
                    isLate: false,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final output = KernelTreePrinter().print(tree);
      expect(output, contains('package:app/main.dart'));
      expect(output, contains('void main()'));
      expect(output, contains('class Foo'));
      expect(output, contains('final String bar'));
    });
  });
}

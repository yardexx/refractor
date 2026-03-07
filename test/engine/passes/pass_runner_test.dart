import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_runner.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

/// A test pass that records when it was run.
class _TrackingPass extends Pass {
  _TrackingPass(this.name);

  @override
  final String name;

  bool wasRun = false;
  int runOrder = -1;

  static int _globalOrder = 0;

  @override
  void run(Component component, PassContext context) {
    wasRun = true;
    runOrder = _globalOrder++;
  }

  static void resetOrder() => _globalOrder = 0;
}

/// A pass that mutates the component by adding a class to the first user lib.
class _MutatingPass extends Pass {
  @override
  String get name => 'mutating';

  @override
  void run(Component component, PassContext context) {
    for (final lib in component.libraries) {
      if (context.shouldObfuscateLibrary(lib)) {
        lib.addClass(Class(name: 'Injected', fileUri: lib.fileUri));
        break;
      }
    }
  }
}

void main() {
  group('PassRunner', () {
    late Component component;

    setUp(() {
      _TrackingPass.resetOrder();
      final coreLib = makeDartCoreLibrary();
      final userLib = makeUserLibrary();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
    });

    test('runs passes in order and returns (Component, SymbolTable)', () {
      final pass1 = _TrackingPass('first');
      final pass2 = _TrackingPass('second');
      final pass3 = _TrackingPass('third');

      final runner = PassRunner(passes: [pass1, pass2, pass3]);
      final (result, symbolTable) = runner.run(
        component,
        const PassOptions(),
        projectRootUri: Uri.directory('/virtual/project'),
      );

      expect(pass1.wasRun, isTrue);
      expect(pass2.wasRun, isTrue);
      expect(pass3.wasRun, isTrue);
      expect(pass1.runOrder, lessThan(pass2.runOrder));
      expect(pass2.runOrder, lessThan(pass3.runOrder));
      expect(result, isA<Component>());
      expect(symbolTable, isNotNull);
    });

    test('empty pass list returns component unchanged', () {
      final runner = PassRunner(passes: []);
      final libraryCount = component.libraries.length;
      final (result, symbolTable) = runner.run(
        component,
        const PassOptions(),
        projectRootUri: Uri.directory('/virtual/project'),
      );

      expect(result.libraries, hasLength(libraryCount));
      expect(symbolTable.size, equals(0));
    });

    test('multiple passes are all applied sequentially', () {
      final mutating = _MutatingPass();
      final tracker = _TrackingPass('after');

      final runner = PassRunner(passes: [mutating, tracker]);
      final (result, _) = runner.run(
        component,
        const PassOptions(),
        projectRootUri: Uri.directory('/virtual/project'),
        projectPackageName: 'refractor',
      );

      // Mutating pass should have added a class.
      final userLib = result.libraries.firstWhere(
        (l) => l.importUri.toString().contains('refractor'),
      );
      expect(
        userLib.classes.any((c) => c.name == 'Injected'),
        isTrue,
      );
      // Tracker should have also run.
      expect(tracker.wasRun, isTrue);
    });
  });
}

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/engine/runner/pass.dart';
import 'package:refractor/src/engine/runner/pass_results.dart';
import 'package:refractor/src/engine/runner/pass_runner.dart';
import 'package:refractor/src/utils/result.dart';
import 'package:test/test.dart';

import '../../helpers/kernel_helpers.dart';

/// A test pass that records when it was run.
class _TrackingPass extends Pass<void> {
  _TrackingPass(this.name);

  @override
  final String name;

  bool wasRun = false;
  int runOrder = -1;

  static int _globalOrder = 0;

  @override
  Future<Result<void>> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    wasRun = true;
    runOrder = _globalOrder++;
    return const Result.ok(null);
  }

  static void resetOrder() => _globalOrder = 0;
}

/// A pass that mutates the component by adding a class to the first user lib.
class _MutatingPass extends Pass<void> {
  @override
  String get name => 'mutating';

  @override
  Future<Result<void>> run(
    Component component,
    ObfuscationTarget target,
  ) async {
    for (final lib in component.libraries) {
      if (target.shouldObfuscateLibrary(lib)) {
        lib.addClass(Class(name: 'Injected', fileUri: lib.fileUri));
        break;
      }
    }
    return const Result.ok(null);
  }
}

void main() {
  group('PassRunner', () {
    late Component component;
    late ObfuscationTarget target;

    setUp(() {
      _TrackingPass.resetOrder();
      final coreLib = makeDartCoreLibrary();
      final userLib = makeUserLibrary();
      component = makeComponent(coreLib: coreLib, userLib: userLib);
      target = makeObfuscationTarget();
    });

    test('runs passes in order and returns PassResults', () async {
      final pass1 = _TrackingPass('first');
      final pass2 = _TrackingPass('second');
      final pass3 = _TrackingPass('third');

      final runner = PassRunner(passes: [pass1, pass2, pass3]);
      final result = await runner.run(component, target);

      expect(result, isA<Ok<PassResults>>());
      expect(pass1.wasRun, isTrue);
      expect(pass2.wasRun, isTrue);
      expect(pass3.wasRun, isTrue);
      expect(pass1.runOrder, lessThan(pass2.runOrder));
      expect(pass2.runOrder, lessThan(pass3.runOrder));
    });

    test('empty pass list returns component unchanged', () async {
      final runner = PassRunner(passes: []);
      final libraryCount = component.libraries.length;
      final result = await runner.run(component, target);

      expect(result, isA<Ok<PassResults>>());
      expect(component.libraries, hasLength(libraryCount));
    });

    test('multiple passes are all applied sequentially', () async {
      final mutating = _MutatingPass();
      final tracker = _TrackingPass('after');

      final runner = PassRunner(passes: [mutating, tracker]);
      await runner.run(component, target);

      // Mutating pass should have added a class.
      final userLib = component.libraries.firstWhere(
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

import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/pass_runner.dart';
import 'package:test/test.dart';

import '../helpers/kernel_helpers.dart';

/// A test pass that records when it was run.
class _TrackingPass extends Pass {
  _TrackingPass(this.name, {this.artifact});

  @override
  final String name;
  final PassArtifact? artifact;

  bool wasRun = false;
  int runOrder = -1;

  static int _globalOrder = 0;

  @override
  Future<PassResult> run(Component component) async {
    wasRun = true;
    runOrder = _globalOrder++;
    return PassSucceeded(
      artifact: artifact,
      report: PassReport(passName: name),
    );
  }

  static void resetOrder() => _globalOrder = 0;
}

/// A pass that mutates the component by adding a class to the first user lib.
class _MutatingPass extends Pass {
  @override
  String get name => 'mutating';

  @override
  Future<PassResult> run(Component component) async {
    _injectClass(component);
    return const PassSucceeded(
      report: PassReport(passName: 'mutating'),
    );
  }
}

/// A pass that partially mutates the component and then fails, modelling an
/// error encountered mid-transformation.
class _MutatingFailingPass extends Pass {
  @override
  String get name => 'mutating-failing';

  @override
  Future<PassResult> run(Component component) async {
    _injectClass(component);
    return PassFailed(
      error: Exception('boom after mutation'),
      report: PassReport(passName: name, message: 'boom after mutation'),
    );
  }
}

class _FailingPass extends Pass {
  _FailingPass(this.name);

  @override
  final String name;

  @override
  Future<PassResult> run(Component component) async {
    return PassFailed(
      error: Exception('boom'),
      report: PassReport(passName: name, message: 'boom'),
    );
  }
}

void _injectClass(Component component) {
  for (final lib in component.libraries) {
    if (lib.importUri.scheme == 'package' &&
        lib.importUri.pathSegments.isNotEmpty &&
        lib.importUri.pathSegments.first == 'refractor') {
      lib.addClass(Class(name: 'Injected', fileUri: lib.fileUri));
      break;
    }
  }
}

bool _hasInjectedClass(Component component) {
  final userLib = component.libraries.firstWhere(
    (l) => l.importUri.toString().contains('refractor'),
  );
  return userLib.classes.any((c) => c.name == 'Injected');
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

    test('runs passes in order and returns PassResults', () async {
      final pass1 = _TrackingPass('first');
      final pass2 = _TrackingPass('second');
      final pass3 = _TrackingPass('third');

      final runner = PassRunner(passes: [pass1, pass2, pass3]);
      final result = await runner.run(component);

      expect(result, isA<PassResults>());
      expect(pass1.wasRun, isTrue);
      expect(pass2.wasRun, isTrue);
      expect(pass3.wasRun, isTrue);
      expect(pass1.runOrder, lessThan(pass2.runOrder));
      expect(pass2.runOrder, lessThan(pass3.runOrder));
      expect(result.reports.map((report) => report.passName), [
        'first',
        'second',
        'third',
      ]);
      expect(result.skipped, isEmpty);
    });

    test('empty pass list returns component unchanged', () async {
      final runner = PassRunner(passes: []);
      final libraryCount = component.libraries.length;
      final result = await runner.run(component);

      expect(result, isA<PassResults>());
      expect(component.libraries, hasLength(libraryCount));
    });

    test('multiple passes are all applied sequentially', () async {
      final mutating = _MutatingPass();
      final tracker = _TrackingPass('after');

      final runner = PassRunner(passes: [mutating, tracker]);
      await runner.run(component);

      expect(_hasInjectedClass(component), isTrue);
      expect(tracker.wasRun, isTrue);
    });

    test('stops at the first failure and does not run later passes', () async {
      final failing = _FailingPass('failing');
      final tracker = _TrackingPass('after');

      final runner = PassRunner(passes: [failing, tracker]);
      final result = await runner.run(component);

      expect(tracker.wasRun, isFalse);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.passName, 'failing');
      expect(result.reports.map((report) => report.passName), ['failing']);
      expect(result.skipped, ['after']);
    });

    test('records every remaining pass as skipped after a failure', () async {
      final failing = _FailingPass('failing');
      final first = _TrackingPass('first-after');
      final second = _TrackingPass('second-after');

      final runner = PassRunner(passes: [failing, first, second]);
      final result = await runner.run(component);

      expect(first.wasRun, isFalse);
      expect(second.wasRun, isFalse);
      expect(result.skipped, ['first-after', 'second-after']);
    });

    test('failure after partial mutation stops later passes', () async {
      final mutatingFailing = _MutatingFailingPass();
      final tracker = _TrackingPass('after');

      final runner = PassRunner(passes: [mutatingFailing, tracker]);
      final result = await runner.run(component);

      expect(tracker.wasRun, isFalse);
      expect(result.failures.single.passName, 'mutating-failing');
      expect(result.skipped, ['after']);
    });

    test('retains the primary failure without collecting later ones', () async {
      final first = _FailingPass('first-fail');
      final second = _FailingPass('second-fail');

      final runner = PassRunner(passes: [first, second]);
      final result = await runner.run(component);

      expect(result.failures, hasLength(1));
      expect(result.failures.single.passName, 'first-fail');
      expect(result.skipped, ['second-fail']);
    });

    test('artifacts from passes before a failure are retained', () async {
      final before = _TrackingPass(
        'before',
        artifact: const _TrackingArtifact('tracked'),
      );
      final failing = _FailingPass('failing');

      final runner = PassRunner(passes: [before, failing]);
      final result = await runner.run(component);

      expect(result.failures.single.passName, 'failing');
      expect(result.artifact<_TrackingArtifact>('before')?.value, 'tracked');
      expect(result.skipped, isEmpty);
    });
  });
}

final class _TrackingArtifact extends PassArtifact {
  const _TrackingArtifact(this.value);

  final String value;

  @override
  Map<String, Object?> toJson() => {
    'value': value,
  };
}

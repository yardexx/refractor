@Tags(['integration'])
library;

import 'dart:io';

import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:refractor/src/engine/passes/rename/reporting/rename_artifact.dart';
import 'package:refractor/src/symbolication/symbol_map.dart';
import 'package:refractor/src/symbolication/symbolicator.dart';
import 'package:test/test.dart';

void main() {
  group('symbol map round-trip', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('symmap_rt'));
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'every emitted entry recovers its original via scoped lookup',
      () async {
        final root = dir.resolveSymbolicLinksSync();
        final appDart = '$root/app.dart';
        // Public class + method (bare keys) and a used private method (scoped
        // key `<library>::_x`), so the map exercises both lookup paths.
        File(appDart).writeAsStringSync('''
class Service {
  int _compute(int x) => x * 2;
  int run(int x) => _compute(x) + 1;
}

void main() {
  print(Service().run(3));
}
''');

        final engine = RefractorEngine(
          compiler: DartCompiler(),
          kernelIO: FileKernelIO(),
        );
        final config = RefractorConfig.fromYaml('''
refractor:
  passes:
    rename: true
    string_encrypt: false
''');
        final result = await engine.run(
          config: config,
          request: BuildRequest(
            input: appDart,
            output: '$root/out.dill',
            target: Target.kernel,
            workDirectory: root,
            projectRootUri: Uri.directory('$root/'),
            projectPackageName: null,
          ),
        );

        final rename = result.passResults.artifact<RenameArtifact>('rename');
        expect(rename, isNotNull);
        final map = SymbolMap(symbols: rename!.mapping.symbolMap);

        expect(map.symbols, isNotEmpty);
        // The fixture must have produced both a bare (public) and a scoped
        // (private) key, so the round-trip below covers both paths.
        expect(
          map.symbols.keys.any((k) => k.contains('::')),
          isTrue,
          reason: 'expected a scoped private entry',
        );
        expect(
          map.symbols.keys.any((k) => !k.contains('::')),
          isTrue,
          reason: 'expected a bare public entry',
        );

        // Property: every entry recovers its original when looked up with the
        // scope its key encodes.
        map.symbols.forEach((key, original) {
          final separator = key.lastIndexOf('::');
          final scope = separator == -1 ? null : key.substring(0, separator);
          final obfuscated = separator == -1
              ? key
              : key.substring(separator + 2);
          expect(
            map.lookup(obfuscated, scope: scope),
            original,
            reason: 'entry "$key" did not round-trip',
          );
        });

        // The originals must include the fixture's declarations.
        expect(map.symbols.values, containsAll(<String>['Service', 'run']));

        // End-to-end: a frame built from a scoped private entry symbolicates
        // back to the original via the Symbolicator's frame-context lookup.
        final scopedEntry = map.symbols.entries.firstWhere(
          (e) => e.key.contains('::'),
        );
        final separator = scopedEntry.key.lastIndexOf('::');
        final scope = scopedEntry.key.substring(0, separator);
        final obfuscated = scopedEntry.key.substring(separator + 2);
        final symbolicated = Symbolicator(map).symbolicateLine(
          '#0      Service.$obfuscated ($scope:1:1)',
        );
        expect(symbolicated, contains(scopedEntry.value));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

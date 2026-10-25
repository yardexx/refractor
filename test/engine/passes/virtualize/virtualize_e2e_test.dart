// End-to-end proof that the virtualization pass produces correct, runnable
// kernel: compile a real sample, run the pass, verify, re-serialize, execute,
// and confirm each virtualized function matches its plain-arithmetic control.
//
// Uses the repo's own package_config so the sample can import
// `package:refractor_annotation` without a separate `pub get`.
// ignore_for_file: lines_longer_than_80_chars

@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:kernel/kernel.dart';
import 'package:path/path.dart' as p;
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/passes/virtualize/config/virtualize_config.dart';
import 'package:refractor/src/engine/passes/virtualize/virtualize_pass.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:test/test.dart';

const _sample = r'''
import 'package:refractor_annotation/refractor_annotation.dart';

@Refractor.virtualize()
int xform(int s) => (((s * 48271 + 0x1234567) ^ 0x5A5A5A5A) & 0xFFFFFF) << 3;

@Refractor.virtualize()
bool check(int s) =>
    ((((s * 48271 + 0x1234567) ^ 0x5A5A5A5A) & 0xFFFFFF) << 3) == 0x0ABC120;

@Refractor.virtualize()
int branchy(int s) => ((s & 1) == 0) ? (s << 5) : (s - 7);

int _xformPlain(int s) => (((s * 48271 + 0x1234567) ^ 0x5A5A5A5A) & 0xFFFFFF) << 3;
bool _checkPlain(int s) =>
    ((((s * 48271 + 0x1234567) ^ 0x5A5A5A5A) & 0xFFFFFF) << 3) == 0x0ABC120;
int _branchyPlain(int s) => ((s & 1) == 0) ? (s << 5) : (s - 7);

void main() {
  const inputs = [42, 0, 1, 7, -5, 123456, 11217657, 999983];
  for (final s in inputs) {
    if (xform(s) != _xformPlain(s)) {
      print('MISMATCH xform $s: ${xform(s)} != ${_xformPlain(s)}');
      return;
    }
    if (check(s) != _checkPlain(s)) {
      print('MISMATCH check $s');
      return;
    }
    if (branchy(s) != _branchyPlain(s)) {
      print('MISMATCH branchy $s');
      return;
    }
  }
  print('ALL_EQUAL check(11217657)=${check(11217657)}');
}
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('refractor_virt_e2e_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test(
    'virtualized functions match plain controls through the full pipeline',
    () async {
      final repoRoot = await _repoRoot();
      final packageConfig = p.join(
        repoRoot,
        '.dart_tool',
        'package_config.json',
      );
      final sourcePath = p.join(tempDir.path, 'main.dart');
      final dillPath = p.join(tempDir.path, 'main.dill');
      final outPath = p.join(tempDir.path, 'main.virt.dill');
      File(sourcePath).writeAsStringSync(_sample);

      // Compile to kernel using the repo's package resolution.
      final compile = Process.runSync('dart', [
        'compile',
        'kernel',
        '--packages=$packageConfig',
        sourcePath,
        '-o',
        dillPath,
      ]);
      expect(
        compile.exitCode,
        0,
        reason: 'compile kernel failed: ${compile.stderr}',
      );

      // Run the virtualization pass.
      final component = loadComponentFromBinary(dillPath);
      final pass = VirtualizePass(
        config: const VirtualizePassConfig(enabled: true),
        projectScope: ProjectScope(
          projectRootUri: Uri.directory('${tempDir.path}/'),
          projectPackageName: null,
        ),
      );
      final result = await pass.run(component);

      expect(result, isA<PassSucceeded>(), reason: result.report.message);
      expect(result.report.metadata['functions_virtualized'], '3');

      // Re-serialize and execute; every virtualized function must match control.
      await writeComponentToBinary(component, outPath);
      final run = Process.runSync('dart', [outPath]);
      expect(run.exitCode, 0, reason: 'run failed: ${run.stderr}');
      final stdout = (run.stdout as String).trim();
      expect(stdout, isNot(contains('MISMATCH')));
      expect(stdout, equals('ALL_EQUAL check(11217657)=true'));
    },
  );
}

Future<String> _repoRoot() async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:refractor/refractor.dart'),
  );
  if (packageUri == null || packageUri.scheme != 'file') {
    throw StateError('Unable to resolve package:refractor/refractor.dart');
  }
  return p.normalize(p.join(p.dirname(p.fromUri(packageUri)), '..'));
}

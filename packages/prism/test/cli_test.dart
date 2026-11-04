@TestOn('vm')
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs the real `bin/prism.dart` entry point to pin the CLI's exit-code
/// contract: 0 = pass, 1 = a band failed, 64 = usage error (including
/// malformed or unreadable inputs, which must never surface as an unhandled
/// exception).
void main() {
  late Directory tempDir;
  late String prismBin;

  setUpAll(() async {
    final libUri = await Isolate.resolvePackageUri(
      Uri.parse('package:prism/prism.dart'),
    );
    if (libUri == null || libUri.scheme != 'file') {
      throw StateError('cannot resolve package:prism');
    }
    prismBin = p.normalize(
      p.join(p.dirname(File.fromUri(libUri).path), '..', 'bin', 'prism.dart'),
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('prism_cli_');
    _write(tempDir, 'app.bin', 'header SecretAlgorithm end');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<ProcessResult> prism(List<String> args) => Process.run(
        Platform.resolvedExecutable,
        ['run', prismBin, ...args],
        workingDirectory: tempDir.path,
      );

  test('exits 0 when every band passes', () async {
    _write(tempDir, 'ok.yaml', 'assertions:\n  - must_not_contain: [Gone]\n');

    final result = await prism(['verify', 'app.bin', '--policy', 'ok.yaml']);

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('exits 1 when a band fails', () async {
    _write(tempDir, 'map.json', '{"a": "SecretAlgorithm"}');

    final result = await prism(['verify', 'app.bin', '--map', 'map.json']);

    expect(result.exitCode, 1, reason: '${result.stderr}');
  });

  final malformed = {
    'policy with an invalid regex': [
      'bad.yaml',
      'assertions:\n  - must_not_match: "sk_(["\n',
      '--policy',
    ],
    'policy without an assertions list': [
      'bad.yaml',
      'assertions: nope\n',
      '--policy',
    ],
    'policy that is not valid YAML': [
      'bad.yaml',
      'assertions: [unclosed\n',
      '--policy',
    ],
    'symbol map that is not a JSON object': [
      'bad.json',
      '[1, 2]',
      '--map',
    ],
    'symbol map that is not valid JSON': [
      'bad.json',
      '{"a": ',
      '--map',
    ],
  };

  for (final MapEntry(key: description, value: [file, content, flag])
      in malformed.entries) {
    test('exits 64 with a clear message for a $description', () async {
      _write(tempDir, file, content);

      final result = await prism(['verify', 'app.bin', flag, file]);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('invalid'));
      expect(result.stderr, isNot(contains('Unhandled exception')));
    });
  }
}

void _write(Directory dir, String name, String content) =>
    File(p.join(dir.path, name)).writeAsStringSync(content);

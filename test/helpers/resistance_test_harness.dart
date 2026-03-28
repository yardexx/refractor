import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/engine/compiler/dart_compiler.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/kernel/file_kernel_io.dart';
import 'package:yaml/yaml.dart';

class ResistanceFixture {
  ResistanceFixture({
    required this.name,
    required this.fixtureDir,
    required this.sourcePath,
    required this.configPath,
    required this.expectationsPath,
    required this.config,
    required this.expectations,
  });

  factory ResistanceFixture.load(String name) {
    final repoRoot = _repoRoot();
    final fixtureDir = Directory(
      p.join(repoRoot, 'test', 'fixtures', 'resistance', name),
    );

    final sourcePath = p.join(fixtureDir.path, 'main.dart');
    final configPath = p.join(fixtureDir.path, 'refractor.yaml');
    final expectationsPath = p.join(fixtureDir.path, 'expectations.yaml');

    return ResistanceFixture(
      name: name,
      fixtureDir: fixtureDir,
      sourcePath: sourcePath,
      configPath: configPath,
      expectationsPath: expectationsPath,
      config: RefractorConfig.fromYaml(File(configPath).readAsStringSync()),
      expectations: ResistanceExpectations.fromYaml(
        File(expectationsPath).readAsStringSync(),
      ),
    );
  }

  final String name;
  final Directory fixtureDir;
  final String sourcePath;
  final String configPath;
  final String expectationsPath;
  final RefractorConfig config;
  final ResistanceExpectations expectations;
}

String _repoRoot() {
  final packageUri = Isolate.resolvePackageUriSync(
    Uri.parse('package:refractor/refractor.dart'),
  );
  if (packageUri == null || packageUri.scheme != 'file') {
    throw StateError('Unable to resolve package:refractor/refractor.dart');
  }

  return p.normalize(
    p.join(p.dirname(p.fromUri(packageUri)), '..'),
  );
}

class ResistanceExpectations {
  ResistanceExpectations({
    this.denylist = const [],
    this.allowlist = const [],
    this.renameHelpers = const [],
    this.requiredMetrics = const {},
  });

  factory ResistanceExpectations.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString);
    if (yaml is! YamlMap) {
      throw const FormatException('Expectation file root must be a mapping.');
    }

    final map = _yamlToMap(yaml);
    if (map is! Map<String, Object?>) {
      throw const FormatException('Expectation file root must be a mapping.');
    }
    final denylist = _stringList(map['denylist']);
    final allowlist = _stringList(map['allowlist']);
    final renameHelpers = _stringList(map['rename_helpers']);
    final requiredMetrics = <String, int>{};
    final rawMetrics = map['required_metrics'];
    if (rawMetrics != null) {
      if (rawMetrics is! Map) {
        throw const FormatException(
          'required_metrics must be a mapping of metric name to minimum value.',
        );
      }
      for (final entry in rawMetrics.entries) {
        final value = entry.value;
        if (value is! int) {
          throw FormatException(
            'Metric "${entry.key}" must have an integer minimum value.',
          );
        }
        requiredMetrics[entry.key.toString()] = value;
      }
    }

    return ResistanceExpectations(
      denylist: denylist,
      allowlist: allowlist,
      renameHelpers: renameHelpers,
      requiredMetrics: requiredMetrics,
    );
  }

  final List<String> denylist;
  final List<String> allowlist;
  final List<String> renameHelpers;
  final Map<String, int> requiredMetrics;
}

class ResistanceRunResult {
  ResistanceRunResult({
    required this.fixture,
    required this.outputPath,
    required this.buildResult,
    required this.stringsPath,
    required this.normalizedStringsOutput,
  });

  final ResistanceFixture fixture;
  final String outputPath;
  final BuildResult buildResult;
  final String stringsPath;
  final List<String> normalizedStringsOutput;
}

String? findStringsExecutable() {
  final path = Platform.environment['PATH'];
  if (path == null || path.isEmpty) return null;

  for (final entry in path.split(Platform.isWindows ? ';' : ':')) {
    if (entry.isEmpty) continue;
    final candidate = File(p.join(entry, 'strings'));
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }

  return null;
}

Future<ResistanceRunResult> buildResistanceFixture(
  ResistanceFixture fixture,
  Directory tempDir,
) async {
  final outputPath = p.join(tempDir.path, '${fixture.name}.exe');

  final engine = RefractorEngine(
    compiler: DartCompiler(),
    kernelIO: FileKernelIO(),
  );

  final buildResult = await engine.run(
    config: fixture.config,
    request: BuildRequest(
      input: fixture.sourcePath,
      output: outputPath,
      target: Target.exe,
      workDirectory: tempDir.path,
      projectRootUri: Uri.directory('${fixture.fixtureDir.path}/'),
      projectPackageName: null,
    ),
  );

  final stringsPath = findStringsExecutable();
  if (stringsPath == null) {
    throw const ProcessException(
      'strings',
      [],
      'Unable to locate `strings` on PATH.',
    );
  }

  final stringsResult = Process.runSync(stringsPath, [outputPath]);
  if (stringsResult.exitCode != 0) {
    throw ProcessException(
      stringsPath,
      [outputPath],
      'strings failed with exit code ${stringsResult.exitCode}: '
      '${stringsResult.stderr}',
      stringsResult.exitCode,
    );
  }

  return ResistanceRunResult(
    fixture: fixture,
    outputPath: outputPath,
    buildResult: buildResult,
    stringsPath: stringsPath,
    normalizedStringsOutput: normalizeStringsOutput(
      stringsResult.stdout as String,
    ),
  );
}

List<String> normalizeStringsOutput(String output) {
  return output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

int metricValue(BuildResult result, String metricName) {
  final parts = metricName.split('.');
  if (parts.length != 2) {
    throw FormatException(
      'Metric name must use "<pass>.<metric>" format: $metricName',
    );
  }

  final report = result.reports.where((report) => report.passName == parts[0]);
  for (final passReport in report) {
    final value = passReport.metadata[parts[1]];
    if (value != null) {
      return int.tryParse(value) ?? 0;
    }
  }

  return 0;
}

bool outputContains(List<String> lines, String needle) {
  return lines.any((line) => line.contains(needle));
}

Object? _yamlToMap(Object? node) => switch (node) {
  YamlMap() => node.map((k, v) => MapEntry(k.toString(), _yamlToMap(v))),
  YamlList() => node.map(_yamlToMap).toList(),
  _ => node,
};

List<String> _stringList(Object? rawValue) {
  if (rawValue == null) return const [];
  if (rawValue is! List) {
    throw const FormatException('Expected a YAML list of strings.');
  }

  return rawValue.map((item) => item.toString()).toList(growable: false);
}

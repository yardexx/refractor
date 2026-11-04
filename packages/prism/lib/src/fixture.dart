import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:prism/src/expectations.dart';
import 'package:refractor/testing.dart';

/// A single prism scenario: a `main.dart`, its `refractor.yaml`, and the
/// `expectations.yaml` contract, all living in one directory.
class Fixture {
  Fixture({
    required this.name,
    required this.directory,
    required this.sourcePath,
    required this.config,
    required this.expectations,
    this.packageName,
  });

  /// Loads a fixture rooted at [directory].
  ///
  /// Expects `main.dart`, `refractor.yaml`, and `expectations.yaml` inside it.
  factory Fixture.load(String directory, {String? name}) {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw StateError('Fixture directory not found: $directory');
    }

    final sourcePath = p.join(dir.path, 'main.dart');
    final configPath = p.join(dir.path, 'refractor.yaml');
    final expectationsPath = p.join(dir.path, 'expectations.yaml');

    return Fixture(
      name: name ?? p.basename(dir.path),
      directory: dir,
      sourcePath: sourcePath,
      config: RefractorConfig.fromYaml(File(configPath).readAsStringSync()),
      expectations: Expectations.fromYaml(
        File(expectationsPath).readAsStringSync(),
      ),
    );
  }

  final String name;
  final Directory directory;
  final String sourcePath;
  final RefractorConfig config;
  final Expectations expectations;

  /// Package name for the fixture, or `null` for a standalone-file fixture
  /// that imports only `dart:` libraries.
  final String? packageName;

  Uri get rootUri => Uri.directory('${directory.path}/');
}

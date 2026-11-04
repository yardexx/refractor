import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spectrometer/spectrometer.dart';
import 'package:test/test.dart';

void main() {
  test('a relative fixture path resolves to an absolute project root', () {
    // `dart test` runs from the package root, so this path is relative.
    const relative = 'test/fixtures/rename';
    expect(Directory(relative).existsSync(), isTrue);

    final fixture = Fixture.load(relative);

    expect(p.isAbsolute(fixture.directory.path), isTrue);
    expect(p.isAbsolute(fixture.sourcePath), isTrue);
    expect(fixture.rootUri.isAbsolute, isTrue);
    expect(fixture.rootUri.scheme, 'file');
    expect(fixture.name, 'rename');
  });
}

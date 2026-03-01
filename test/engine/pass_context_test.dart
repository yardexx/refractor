import 'dart:io';

import 'package:glob/glob.dart';
import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass_context.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:test/test.dart';

void main() {
  group('PassContext.shouldObfuscateLibrary', () {
    PassContext makeContext([PassOptions? options]) {
      return PassContext(
        symbolTable: SymbolTable(),
        nameGenerator: NameGenerator(),
        options: options ?? const PassOptions(),
      );
    }

    Library makeLibrary(String uri) {
      final parsed = Uri.parse(uri);
      return Library(parsed, fileUri: parsed);
    }

    test('never obfuscates dart: libraries', () {
      final context = makeContext();

      expect(context.shouldObfuscateLibrary(makeLibrary('dart:core')), isFalse);
    });

    test('rejects non-project package libraries', () {
      final context = makeContext();
      expect(
        context.shouldObfuscateLibrary(
          makeLibrary('package:other_package/main.dart'),
        ),
        isFalse,
      );
    });

    test('obfuscates only files inside current project folder', () {
      final context = makeContext();
      final inProjectUri = Uri.file(
        '${Directory.current.path}'
        '${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}main.dart',
      );

      expect(
        context.shouldObfuscateLibrary(
          makeLibrary(inProjectUri.toString()),
        ),
        isTrue,
      );
      expect(
        context.shouldObfuscateLibrary(
          makeLibrary('file:///another/place/lib/main.dart'),
        ),
        isFalse,
      );
    });

    test('exclude patterns can block by import URI string', () {
      final context = makeContext(
        PassOptions(excludeLibraryUriPatterns: [Glob('**/generated/**')]),
      );

      expect(
        context.shouldObfuscateLibrary(
          makeLibrary('package:my_app/generated/file.dart'),
        ),
        isFalse,
      );
    });

    test('rejects non-project file URIs by default', () {
      final context = makeContext();

      expect(
        context.shouldObfuscateLibrary(
          makeLibrary('file:///outside/project/main.dart'),
        ),
        isFalse,
      );
    });
  });
}

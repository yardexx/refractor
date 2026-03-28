import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/reporting/github_reporter.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:refractor/src/engine/symbol_table.dart';
import 'package:test/test.dart';

void main() {
  group('GitHubActionsSummaryReporter', () {
    final reporter = GitHubReporter(Logger());

    test('renders metrics in report order with human labels', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: ['rename', 'string_encrypt'],
        reports: const [
          PassReport(
            passName: 'rename',
            metadata: {
              'classes': '1',
              'members': '2',
              'variables': '3',
            },
          ),
          PassReport(
            passName: 'string_encrypt',
            metadata: {
              'strings_encrypted': '4',
            },
          ),
        ],
      );

      expect(
        reporter.render(result),
        '''
# ✅ Refractor Build Summary

Build output: `build/out.dill` for GitHub Actions job summary.
Passes succeeded: 2. Passes failed: 0.

## ✅ rename
- Classes renamed: 1
- Members renamed: 2
- Variables renamed: 3

## ✅ string_encrypt
- Strings encrypted: 4''',
      );
    });

    test('renders empty successful reports explicitly', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: ['string_encrypt'],
        reports: const [
          PassReport(passName: 'string_encrypt'),
        ],
      );

      expect(
        reporter.render(result),
        '''
# ✅ Refractor Build Summary

Build output: `build/out.dill` for GitHub Actions job summary.
Passes succeeded: 1. Passes failed: 0.

## ✅ string_encrypt
(Nothing to report)''',
      );
    });

    test('renders failures with message and underlying error', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: ['string_encrypt'],
        reports: const [
          PassReport(passName: 'string_encrypt', message: 'boom'),
        ],
        failures: [
          PassFailureRecord(
            passName: 'string_encrypt',
            error: Exception('kaboom'),
          ),
        ],
      );

      expect(
        reporter.render(result),
        '''
# ⚠️ Refractor Build Summary

Build output: `build/out.dill` for GitHub Actions job summary.
Passes succeeded: 0. Passes failed: 1.

## ❌ string_encrypt
(Nothing to report)
Message: boom
Error: Exception: kaboom''',
      );
    });

    test('renders unknown metric keys with readable fallback labels', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: ['custom'],
        reports: const [
          PassReport(
            passName: 'custom',
            metadata: {
              'custom_metric_total': '7',
            },
          ),
        ],
      );

      expect(
        reporter.render(result),
        '''
# ✅ Refractor Build Summary

Build output: `build/out.dill` for GitHub Actions job summary.
Passes succeeded: 1. Passes failed: 0.

## ✅ custom
- Custom Metric Total: 7''',
      );
    });

    test('renders failure-only records even without a matching report', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: const [],
        failures: [
          PassFailureRecord(
            passName: 'rename',
            error: Exception('missing report'),
          ),
        ],
      );

      expect(
        reporter.render(result),
        '''
# ⚠️ Refractor Build Summary

Build output: `build/out.dill` for GitHub Actions job summary.
Passes succeeded: 0. Passes failed: 1.

## ❌ rename
(Nothing to report)
Error: Exception: missing report''',
      );
    });

    test('renders deterministically for the same build result', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        symbolTable: SymbolTable(),
        passesRun: ['rename'],
        reports: const [
          PassReport(
            passName: 'rename',
            metadata: {'classes': '1'},
          ),
        ],
      );

      expect(reporter.render(result), equals(reporter.render(result)));
    });
  });
}

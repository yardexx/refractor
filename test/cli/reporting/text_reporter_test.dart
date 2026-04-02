import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/reporting/text_reporter.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';
import 'package:test/test.dart';

void main() {
  group('TextReporter', () {
    final reporter = TextReporter(Logger());

    test('renders metrics in report order with human labels', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        passesRun: ['rename', 'string_encrypt'],
        passResults: PassResults(),
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
✅ Build report: 2 pass(es) succeeded.

✅ rename:
Classes renamed: 1
Members renamed: 2
Variables renamed: 3

✅ string_encrypt:
Strings encrypted: 4''',
      );
    });

    test('renders empty successful reports explicitly', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        passesRun: ['string_encrypt'],
        passResults: PassResults(),
        reports: const [
          PassReport(passName: 'string_encrypt'),
        ],
      );

      expect(
        reporter.render(result),
        '''
✅ Build report: 1 pass(es) succeeded.

✅ string_encrypt:
(Nothing to report)''',
      );
    });

    test('renders failures with message and underlying error', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        passesRun: ['string_encrypt'],
        passResults: PassResults(),
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
⚠️ Build report: 0 pass(es) succeeded, 1 pass(es) failed.

❌ string_encrypt:
(Nothing to report)
Message: boom
Error: Exception: kaboom''',
      );
    });

    test('renders unknown metric keys with readable fallback labels', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        passesRun: ['custom'],
        passResults: PassResults(),
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
✅ Build report: 1 pass(es) succeeded.

✅ custom:
Custom Metric Total: 7''',
      );
    });

    test('renders failure-only records even without a matching report', () {
      final result = BuildResult(
        outputPath: 'build/out.dill',
        passesRun: const [],
        passResults: PassResults(),
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
⚠️ Build report: 0 pass(es) succeeded, 1 pass(es) failed.

❌ rename:
(Nothing to report)
Error: Exception: missing report''',
      );
    });
  });
}

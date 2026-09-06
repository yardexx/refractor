import 'package:refractor/src/engine/pass/reporting/pass_report.dart';
import 'package:test/test.dart';

void main() {
  group('PassReport', () {
    test('preserves metadata ordering', () {
      const report = PassReport(
        passName: 'rename',
        metadata: {
          'classes': '1',
          'members': '2',
        },
      );

      expect(report.metadata.keys, ['classes', 'members']);
    });

    test('message-only report is not empty', () {
      const report = PassReport(
        passName: 'string_encrypt',
        message: 'failed',
      );

      expect(report.isEmpty, isFalse);
    });

    test('toJson exposes serializable pass report data', () {
      const report = PassReport(
        passName: 'rename',
        message: 'done',
        metadata: {
          'classes': '1',
        },
      );

      expect(report.toJson(), {
        'pass_name': 'rename',
        'message': 'done',
        'metadata': {'classes': '1'},
      });
    });
  });
}

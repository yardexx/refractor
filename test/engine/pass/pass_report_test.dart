import 'package:refractor/src/engine/pass/pass_metric.dart';
import 'package:refractor/src/engine/pass/pass_report.dart';
import 'package:test/test.dart';

void main() {
  group('PassReport', () {
    test('preserves metric ordering', () {
      const report = PassReport(
        passName: 'rename',
        metrics: [
          PassMetric(key: 'classes', value: 1),
          PassMetric(key: 'members', value: 2),
        ],
      );

      expect(
        report.metrics.map((metric) => metric.key),
        ['classes', 'members'],
      );
    });

    test('message-only report is not empty', () {
      const report = PassReport(
        passName: 'string_encrypt',
        message: 'failed',
      );

      expect(report.isEmpty, isFalse);
    });

    test('totalCount sums metric values', () {
      const report = PassReport(
        passName: 'rename',
        metrics: [
          PassMetric(key: 'classes', value: 1),
          PassMetric(key: 'members', value: 2),
          PassMetric(key: 'variables', value: 3),
        ],
      );

      expect(report.totalCount, 6);
    });
  });
}

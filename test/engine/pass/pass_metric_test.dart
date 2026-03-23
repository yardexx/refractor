import 'package:refractor/src/engine/pass/pass_metric.dart';
import 'package:test/test.dart';

void main() {
  group('PassMetric', () {
    test('stores stable key and value', () {
      const metric = PassMetric(key: 'strings_encrypted', value: 3);

      expect(metric.key, 'strings_encrypted');
      expect(metric.value, 3);
    });
  });
}

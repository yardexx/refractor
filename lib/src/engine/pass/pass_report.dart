import 'package:refractor/src/engine/pass/pass_metric.dart';

/// Structured report emitted by a pass execution.
class PassReport {
  const PassReport({
    required this.passName,
    this.metrics = const [],
    this.message,
  });

  final String passName;
  final List<PassMetric> metrics;
  final String? message;

  int get totalCount => metrics.fold(0, (sum, metric) => sum + metric.value);

  bool get isEmpty => metrics.isEmpty && message == null;
}

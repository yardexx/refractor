import 'package:refractor/src/cli/reporting/build_reporter.dart';
import 'package:refractor/src/engine/engine.dart';

final class TextReporter implements BuildReporter {
  @override
  String render(BuildResult result) {
    final buffer = StringBuffer();
    final failureByPass = {
      for (final failure in result.failures) failure.passName: failure,
    };

    buffer.writeln(_buildSummary(result));

    for (final report in result.reports) {
      final failure = failureByPass[report.passName];

      buffer
        ..writeln()
        ..writeln('${failure == null ? '✅' : '❌'} ${report.passName}:');

      if (report.metrics.isEmpty) {
        buffer.writeln('(Nothing to report)');
      } else {
        for (final metric in report.metrics) {
          buffer.writeln('${_labelForMetric(metric.key)}: ${metric.value}');
        }
      }

      if (report.message case final message?) {
        buffer.writeln('Message: $message');
      }

      if (failure case final failure?) {
        buffer.writeln('Error: ${failure.error}');
      }
    }

    for (final failure in result.failures) {
      final hasReport = result.reports.any(
        (report) => report.passName == failure.passName,
      );
      if (hasReport) continue;

      buffer
        ..writeln()
        ..writeln('❌ ${failure.passName}:')
        ..writeln('(Nothing to report)')
        ..writeln('Error: ${failure.error}');
    }

    return buffer.toString().trimRight();
  }

  String _buildSummary(BuildResult result) {
    final totalReports = result.reports.length;
    final totalFailures = result.failures.length;
    final totalSucceeded = totalReports > totalFailures
        ? totalReports - totalFailures
        : 0;

    if (totalFailures == 0) {
      return '✅ Build report: $totalSucceeded pass(es) succeeded.';
    }

    return '⚠️ Build report: $totalSucceeded pass(es) succeeded, '
        '$totalFailures pass(es) failed.';
  }

  String _labelForMetric(String key) {
    const labels = <String, String>{
      'classes': 'Classes renamed',
      'members': 'Members renamed',
      'variables': 'Variables renamed',
      'strings_encrypted': 'Strings encrypted',
    };

    if (labels.containsKey(key)) {
      return labels[key]!;
    }

    return key.split('_').map(_capitalize).join(' ');
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

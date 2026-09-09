import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/reporting/build_reporter.dart';
import 'package:refractor/src/cli/reporting/report_metric_labels.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';

final class TextReporter implements BuildReporter {
  TextReporter(this.logger);

  final Logger logger;

  @override
  void report(BuildResult result) {
    final textReport = render(result);
    logger.info(textReport);
  }

  String render(BuildResult result) {
    final buffer = StringBuffer();
    final failureByPass = _indexFailuresByPass(result);

    _writeSummary(buffer, result);
    _writeReportedPasses(buffer, result, failureByPass);
    _writeFailureOnlyPasses(buffer, result);
    _writeSkippedPasses(buffer, result);

    return buffer.toString().trimRight();
  }

  Map<String, PassFailureRecord> _indexFailuresByPass(BuildResult result) {
    return {
      for (final failure in result.failures) failure.passName: failure,
    };
  }

  void _writeSummary(StringBuffer buffer, BuildResult result) {
    buffer.writeln(_buildSummary(result));
  }

  void _writeReportedPasses(
    StringBuffer buffer,
    BuildResult result,
    Map<String, PassFailureRecord> failureByPass,
  ) {
    for (final report in result.reports) {
      _writePassBlock(
        buffer,
        passName: report.passName,
        metadata: report.metadata,
        message: report.message,
        error: failureByPass[report.passName]?.error.toString(),
      );
    }
  }

  void _writeFailureOnlyPasses(StringBuffer buffer, BuildResult result) {
    for (final failure in result.failures) {
      if (_hasMatchingReport(result, failure.passName)) {
        continue;
      }

      _writePassBlock(
        buffer,
        passName: failure.passName,
        metadata: const {},
        error: failure.error.toString(),
      );
    }
  }

  void _writeSkippedPasses(StringBuffer buffer, BuildResult result) {
    for (final passName in result.skipped) {
      buffer
        ..writeln()
        ..writeln('⏭️ $passName:')
        ..writeln('Skipped: an earlier pass failed.');
    }
  }

  bool _hasMatchingReport(BuildResult result, String passName) {
    return result.reports.any((report) => report.passName == passName);
  }

  void _writePassBlock(
    StringBuffer buffer, {
    required String passName,
    required Map<String, String> metadata,
    String? message,
    String? error,
  }) {
    buffer
      ..writeln()
      ..writeln('${error == null ? '✅' : '❌'} $passName:');

    _writeMetadata(buffer, metadata);

    if (message case final message?) {
      buffer.writeln('Message: $message');
    }

    if (error case final error?) {
      buffer.writeln('Error: $error');
    }
  }

  void _writeMetadata(StringBuffer buffer, Map<String, String> metadata) {
    if (metadata.isEmpty) {
      buffer.writeln('(Nothing to report)');
      return;
    }

    for (final entry in metadata.entries) {
      buffer.writeln('${labelForMetric(entry.key)}: ${entry.value}');
    }
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

    final totalSkipped = result.skipped.length;
    final skippedClause = totalSkipped == 0 ? '' : ', $totalSkipped skipped';
    return '⚠️ Build report: $totalSucceeded pass(es) succeeded, '
        '$totalFailures pass(es) failed$skippedClause.';
  }
}

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:refractor/src/cli/reporting/build_reporter.dart';
import 'package:refractor/src/cli/reporting/report_metric_labels.dart';
import 'package:refractor/src/engine/engine.dart';
import 'package:refractor/src/engine/pass.dart';

final class GitHubReporter implements BuildReporter {
  GitHubReporter(this.logger, {Map<String, String>? environment})
    : _environment = environment;

  final Logger logger;
  final Map<String, String>? _environment;

  @override
  void report(BuildResult result) {
    logger.info(renderTextReport(result));
    _reportGitHubSummary(result);
  }

  String renderTextReport(BuildResult result) {
    final buffer = StringBuffer();
    final failureByPass = _indexFailuresByPass(result);

    _writeTextSummary(buffer, result);
    _writeTextReportedPasses(buffer, result, failureByPass);
    _writeTextFailureOnlyPasses(buffer, result);

    return buffer.toString().trimRight();
  }

  String render(BuildResult result) {
    final buffer = StringBuffer();
    final failureByPass = _indexFailuresByPass(result);

    _writeGitHubSummary(buffer, result);
    _writeGitHubReportedPasses(buffer, result, failureByPass);
    _writeGitHubFailureOnlyPasses(buffer, result);

    return buffer.toString().trimRight();
  }

  void _reportGitHubSummary(BuildResult result) {
    final summaryPath = _summaryPath;
    if (summaryPath == null || summaryPath.isEmpty) {
      return;
    }

    try {
      _appendSummary(summaryPath, '${render(result)}\n\n');
    } on Exception catch (error) {
      logger.detail('GitHub summary emission failed: $error');
    }
  }

  String? get _summaryPath {
    return (_environment ?? Platform.environment)['GITHUB_STEP_SUMMARY'];
  }

  void _appendSummary(String path, String content) {
    File(path).writeAsStringSync(content, mode: FileMode.append);
  }

  Map<String, PassFailureRecord> _indexFailuresByPass(BuildResult result) {
    return {
      for (final failure in result.failures) failure.passName: failure,
    };
  }

  void _writeTextSummary(StringBuffer buffer, BuildResult result) {
    final totalReports = result.reports.length;
    final totalFailures = result.failures.length;
    final totalSucceeded = totalReports > totalFailures
        ? totalReports - totalFailures
        : 0;

    if (totalFailures == 0) {
      buffer.writeln('✅ Build report: $totalSucceeded pass(es) succeeded.');
      return;
    }

    buffer.writeln(
      '⚠️ Build report: $totalSucceeded pass(es) succeeded, '
      '$totalFailures pass(es) failed.',
    );
  }

  void _writeGitHubSummary(StringBuffer buffer, BuildResult result) {
    final totalFailures = result.failures.length;
    final totalSucceeded = result.reports.length > totalFailures
        ? result.reports.length - totalFailures
        : 0;
    final heading = totalFailures == 0
        ? '# ✅ Refractor Build Summary'
        : '# ⚠️ Refractor Build Summary';

    buffer
      ..writeln(heading)
      ..writeln()
      ..writeln(
        'Build output: `${result.outputPath}` for GitHub Actions job summary.',
      )
      ..writeln(
        'Passes succeeded: $totalSucceeded. Passes failed: $totalFailures.',
      );
  }

  void _writeTextReportedPasses(
    StringBuffer buffer,
    BuildResult result,
    Map<String, PassFailureRecord> failureByPass,
  ) {
    for (final report in result.reports) {
      _writeTextPassBlock(
        buffer,
        passName: report.passName,
        metrics: report.metrics,
        message: report.message,
        error: failureByPass[report.passName]?.error.toString(),
      );
    }
  }

  void _writeGitHubReportedPasses(
    StringBuffer buffer,
    BuildResult result,
    Map<String, PassFailureRecord> failureByPass,
  ) {
    for (final report in result.reports) {
      _writeGitHubPassBlock(
        buffer,
        passName: report.passName,
        metrics: report.metrics,
        message: report.message,
        error: failureByPass[report.passName]?.error.toString(),
      );
    }
  }

  void _writeTextFailureOnlyPasses(StringBuffer buffer, BuildResult result) {
    for (final failure in result.failures) {
      if (_hasMatchingReport(result, failure.passName)) {
        continue;
      }

      _writeTextPassBlock(
        buffer,
        passName: failure.passName,
        metrics: const [],
        error: failure.error.toString(),
      );
    }
  }

  void _writeGitHubFailureOnlyPasses(StringBuffer buffer, BuildResult result) {
    for (final failure in result.failures) {
      if (_hasMatchingReport(result, failure.passName)) {
        continue;
      }

      _writeGitHubPassBlock(
        buffer,
        passName: failure.passName,
        metrics: const [],
        error: failure.error.toString(),
      );
    }
  }

  bool _hasMatchingReport(BuildResult result, String passName) {
    return result.reports.any((report) => report.passName == passName);
  }

  void _writeTextPassBlock(
    StringBuffer buffer, {
    required String passName,
    required List<PassMetric> metrics,
    String? message,
    String? error,
  }) {
    buffer
      ..writeln()
      ..writeln('${error == null ? '✅' : '❌'} $passName:');

    _writeTextMetrics(buffer, metrics);

    if (message case final message?) {
      buffer.writeln('Message: $message');
    }

    if (error case final error?) {
      buffer.writeln('Error: $error');
    }
  }

  void _writeGitHubPassBlock(
    StringBuffer buffer, {
    required String passName,
    required List<PassMetric> metrics,
    String? message,
    String? error,
  }) {
    buffer
      ..writeln()
      ..writeln('## ${error == null ? '✅' : '❌'} $passName');

    _writeGitHubMetrics(buffer, metrics);

    if (message case final message?) {
      buffer.writeln('Message: $message');
    }

    if (error case final error?) {
      buffer.writeln('Error: $error');
    }
  }

  void _writeTextMetrics(StringBuffer buffer, List<PassMetric> metrics) {
    if (metrics.isEmpty) {
      buffer.writeln('(Nothing to report)');
      return;
    }

    for (final metric in metrics) {
      buffer.writeln('${labelForMetric(metric.key)}: ${metric.value}');
    }
  }

  void _writeGitHubMetrics(StringBuffer buffer, List<PassMetric> metrics) {
    if (metrics.isEmpty) {
      buffer.writeln('(Nothing to report)');
      return;
    }

    for (final metric in metrics) {
      buffer.writeln('- ${labelForMetric(metric.key)}: ${metric.value}');
    }
  }
}

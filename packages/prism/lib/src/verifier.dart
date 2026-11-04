import 'package:prism/src/binary_scanner.dart';
import 'package:prism/src/symbol_map.dart';
import 'package:prism/src/verification.dart';

/// Back-checks a built artifact against a Refractor symbol map.
///
/// The oracle is the map's originals: every one of them was supposed to be
/// renamed away, so any that still appears verbatim in the artifact is a leak.
/// No source, no rebuild, no dependency on the Refractor engine.
class Verifier {
  const Verifier({
    this.minConfidentLength = 5,
    this.failOn = Confidence.high,
    this.commonNames = defaultCommonNames,
  });

  /// Originals whose significant length is below this are treated as
  /// low-confidence (too short to distinguish from coincidental bytes).
  final int minConfidentLength;

  /// What severity of leak fails the run. `null` = report-only.
  final Confidence? failOn;

  /// Identifiers that are common enough across any Dart binary (SDK, idioms)
  /// that finding them proves little; always low-confidence.
  final Set<String> commonNames;

  static const Set<String> defaultCommonNames = {
    'value',
    'values',
    'name',
    'index',
    'key',
    'keys',
    'type',
    'data',
    'state',
    'error',
    'length',
    'hash',
    'hashCode',
    'toString',
    'call',
    'build',
    'main',
    'next',
    'add',
    'remove',
    'get',
    'set',
    'id',
    'init',
    'update',
    'close',
    'open',
    'start',
    'stop',
    'run',
    'size',
    'count',
  };

  VerificationReport verify({
    required String artifactPath,
    required SymbolMap symbolMap,
    BinaryScanner? scanner,
  }) {
    final activeScanner = scanner ?? BinaryScanner.ofFile(artifactPath);
    final originals = symbolMap.originals;
    final leaks = <Leak>[];

    for (final original in originals) {
      final match = activeScanner.find(original);
      if (match == null) continue;
      leaks.add(
        Leak(
          original: original,
          offset: match.offset,
          confidence: _classify(original),
        ),
      );
    }

    leaks.sort((a, b) {
      if (a.confidence != b.confidence) {
        return a.confidence == Confidence.high ? -1 : 1;
      }
      return a.original.compareTo(b.original);
    });

    return VerificationReport(
      artifactPath: artifactPath,
      originalsChecked: originals.length,
      leaks: leaks,
      failOn: failOn,
    );
  }

  Confidence _classify(String original) {
    final significant = original.replaceFirst(RegExp('^_+'), '');
    if (significant.length < minConfidentLength) return Confidence.low;
    if (commonNames.contains(original) || commonNames.contains(significant)) {
      return Confidence.low;
    }
    return Confidence.high;
  }
}

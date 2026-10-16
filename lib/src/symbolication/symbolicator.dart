import 'package:refractor/src/symbolication/symbol_map.dart';

/// Rewrites obfuscated identifiers in a stack trace back to their originals
/// using a [SymbolMap].
///
/// It operates on the symbol portion of Dart VM / AOT symbolic frames —
/// `#<n>  <symbol> (<location>)` — replacing identifier tokens that appear in
/// the map and leaving everything else untouched: the `(<location>)` (so file
/// paths that happen to match an obfuscated name are never corrupted), unmapped
/// tokens, and any line that is not a symbolic frame (headers, blank lines,
/// interleaved output).
///
/// This reverses public classes and members and unambiguously-named private
/// members (the rename mapping records those under their bare name too).
/// Scope-aware disambiguation of ambiguous short member names using the
/// enclosing frame is a follow-up.
final class Symbolicator {
  const Symbolicator(this.map);

  final SymbolMap map;

  /// Matches a symbolic frame: the `#<n>` prefix, the symbol, and the trailing
  /// parenthesised location. Non-greedy symbol so the location is the last
  /// `( ... )` group on the line.
  static final RegExp _framePattern = RegExp(
    r'^(\s*#\d+\s+)(.*?)(\s+\([^)]*\))\s*$',
  );

  /// A Dart identifier token.
  static final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

  /// Symbolicates a whole trace, line by line.
  String symbolicateTrace(String trace) {
    return trace.split('\n').map(symbolicateLine).join('\n');
  }

  /// Symbolicates a single line, or returns it unchanged if it is not a
  /// symbolic frame.
  String symbolicateLine(String line) {
    final frame = _framePattern.firstMatch(line);
    if (frame == null) {
      return line;
    }
    final reversed = frame.group(2)!.replaceAllMapped(_identifier, (match) {
      final token = match[0]!;
      return map.originalFor(token) ?? token;
    });
    return '${frame.group(1)}$reversed${frame.group(3)}';
  }
}

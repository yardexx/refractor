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
/// members (the rename mapping records those under their bare name too). For a
/// private member whose short name collides across libraries, it uses the
/// enclosing frame's library URI (from the location) to pick the scoped entry.
final class Symbolicator {
  const Symbolicator(this.map);

  final SymbolMap map;

  /// Matches a symbolic frame: the `#<n>` prefix, the symbol, and the trailing
  /// parenthesised location. Non-greedy symbol so the location is the last
  /// `( ... )` group on the line.
  static final RegExp _framePattern = RegExp(
    r'^(\s*#\d+\s+)(.*?)(\s+\(([^)]*)\))\s*$',
  );

  /// A Dart identifier token.
  static final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

  /// Strips the trailing `:<line>` or `:<line>:<col>` from a frame location,
  /// leaving the library URI.
  static final RegExp _lineColumn = RegExp(r'(?::\d+){1,2}$');

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
    final scope = frame.group(4)!.replaceFirst(_lineColumn, '');
    final reversed = frame.group(2)!.replaceAllMapped(_identifier, (match) {
      final token = match[0]!;
      return map.lookup(token, scope: scope) ?? token;
    });
    return '${frame.group(1)}$reversed${frame.group(3)}';
  }
}

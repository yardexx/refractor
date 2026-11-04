import 'dart:convert';
import 'dart:io';

/// Where a token was found in an artifact.
class TokenMatch {
  const TokenMatch({required this.token, required this.offset});

  final String token;

  /// Byte offset of the first boundary-valid occurrence.
  final int offset;
}

/// Scans a built artifact's raw bytes for exact identifier tokens.
///
/// The bytes are treated as Latin-1 so every byte maps 1:1 to a code unit and
/// offsets stay exact; identifiers are ASCII, so this is lossless for the
/// tokens we search. Matches are **boundary-aware**: an occurrence only counts
/// when the characters immediately around it are not identifier characters, so
/// `start` does not match inside `restart`. This is the single cheapest way to
/// cut false positives on a native binary without parsing it.
class BinaryScanner {
  BinaryScanner(this._haystack);

  factory BinaryScanner.ofFile(String path) =>
      BinaryScanner(latin1.decode(File(path).readAsBytesSync()));

  final String _haystack;

  int get byteLength => _haystack.length;

  /// Returns the first boundary-valid match for [token], or `null`.
  TokenMatch? find(String token) {
    if (token.isEmpty) return null;
    var from = 0;
    while (true) {
      final index = _haystack.indexOf(token, from);
      if (index < 0) return null;
      final end = index + token.length;
      if (!_isIdentChar(_codeUnitOrNull(index - 1)) &&
          !_isIdentChar(_codeUnitOrNull(end))) {
        return TokenMatch(token: token, offset: index);
      }
      from = index + 1;
    }
  }

  /// Byte offset of the first raw (non-boundary) occurrence of [needle], or
  /// `null`. Used for customer secrets/literals, which — unlike identifiers —
  /// should be flagged wherever they appear, even embedded in a larger run.
  int? indexOfRaw(String needle) {
    if (needle.isEmpty) return null;
    final index = _haystack.indexOf(needle);
    return index < 0 ? null : index;
  }

  /// Byte offset of the first match of [pattern], or `null`.
  int? firstMatch(RegExp pattern) => pattern.firstMatch(_haystack)?.start;

  int? _codeUnitOrNull(int i) =>
      (i < 0 || i >= _haystack.length) ? null : _haystack.codeUnitAt(i);

  static bool _isIdentChar(int? unit) {
    if (unit == null) return false;
    final isDigit = unit >= 0x30 && unit <= 0x39;
    final isUpper = unit >= 0x41 && unit <= 0x5A;
    final isLower = unit >= 0x61 && unit <= 0x7A;
    final isUnderscore = unit == 0x5F;
    final isDollar = unit == 0x24;
    return isDigit || isUpper || isLower || isUnderscore || isDollar;
  }
}

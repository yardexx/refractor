import 'dart:convert';
import 'dart:io';

/// Searches a built artifact's raw bytes for literal strings.
///
/// The bytes are decoded as Latin-1, so every byte maps 1:1 to a code unit
/// and offsets stay exact. Matches are raw substrings: a needle is found
/// wherever it appears, with no minimum run length (unlike `strings`) and no
/// dependency on an external tool.
class ByteScanner {
  ByteScanner(this._haystack);

  factory ByteScanner.ofFile(String path) =>
      ByteScanner(latin1.decode(File(path).readAsBytesSync()));

  final String _haystack;

  int get byteLength => _haystack.length;

  /// Byte offset of the first occurrence of [needle], or `null`.
  int? indexOf(String needle) {
    if (needle.isEmpty) return null;
    final index = _haystack.indexOf(needle);
    return index < 0 ? null : index;
  }
}

/// Plain-Dart source of the string-decode runtime helper.
///
/// This is compiled to kernel and injected into the program being obfuscated
/// (see `SourceHelperInjector`), then referenced by the string-encrypt
/// transformer in place of each plaintext literal.
///
/// Authoring it as ordinary Dart — instead of hand-assembling kernel IL —
/// means the decode logic can be read, edited and reasoned about like any
/// other code. It MUST stay the exact inverse of
/// `StringEncryptCodec.encodeWithKey`: XOR each byte with the rolling key byte
/// and reverse. The matching behaviour is covered by the codec's own tests.
library;

/// The top-level function name the injected helper exposes. The transformer
/// resolves the reparented procedure by this name.
const String decodeRuntimeHelperName = 'refractorDecode';

/// The Dart source compiled and injected as the decode helper.
const String decodeRuntimeSource = '''
import 'dart:convert';

@pragma('vm:never-inline')
String refractorDecode(List<int> bytes, int key) {
  final decoded = <int>[];
  var shift = 0;
  for (final byte in bytes.reversed) {
    decoded.add(byte ^ ((key >> shift) & 0xFF));
    shift = (shift + 8) & 24;
  }
  return utf8.decode(decoded);
}

// Required so `dart compile kernel` accepts the helper as an entrypoint. It
// lives in the helper library, which is dropped after `refractorDecode` is
// reparented, so it never reaches the obfuscated program.
void main() {}
''';

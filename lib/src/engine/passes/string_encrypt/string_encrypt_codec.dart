import 'dart:convert';

final class StringEncryptCodec {
  const StringEncryptCodec._();

  static List<int> encodeWithKey(String value, int key) {
    final encoded = <int>[];
    var shift = 0;

    for (final byte in utf8.encode(value)) {
      encoded.add(byte ^ _keyByte(key, shift));
      shift = (shift + 8) & 24;
    }

    return encoded.reversed.toList(growable: false);
  }

  static String decodeWithKey(List<int> bytes, int key) {
    final decoded = <int>[];
    var shift = 0;

    for (final byte in bytes.reversed) {
      decoded.add(byte ^ _keyByte(key, shift));
      shift = (shift + 8) & 24;
    }

    return utf8.decode(decoded);
  }

  static int _keyByte(int key, int shift) => (key >> shift) & 0xFF;
}

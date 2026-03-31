import 'dart:convert';

final class StringEncryptCodec {
  const StringEncryptCodec._();

  static List<int> encodeWithKey(String value, int key) {
    return utf8.encode(value).map((byte) => byte ^ key).toList();
  }
}

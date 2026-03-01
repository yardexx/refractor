/// Generates sequential obfuscated identifiers like `_$0`, `_$1`, etc.
class NameGenerator {
  NameGenerator({this.prefix = r'_$'});

  final String prefix;
  int _counter = 0;

  /// Return the next unique obfuscated name.
  String next() => '$prefix${_counter++}';

  /// Reset the counter (useful between test runs).
  void reset() => _counter = 0;

  /// Peek at the current counter value without incrementing.
  int get currentCount => _counter;
}

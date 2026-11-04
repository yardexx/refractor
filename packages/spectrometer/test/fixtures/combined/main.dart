// A standalone fixture: imports only `dart:` libraries so it builds without
// package resolution. Exercises rename (distinct identifiers) and
// string_encrypt (a secret literal vs. a preserved marker) together.
//
// `vm:never-inline` keeps the renamed members alive in a plain AOT build, so
// their absence after obfuscation proves the rename (see rename/main.dart).

class SecretAlgorithm {
  @pragma('vm:never-inline')
  int computeProfitMargin(int revenue, int cost) => revenue - cost;
}

void main() {
  final algo = SecretAlgorithm();
  print('margin: ${algo.computeProfitMargin(100, 40)}');
  print('token: SecretLaunchCode');
  print('VISIBLE_MARKER');
}

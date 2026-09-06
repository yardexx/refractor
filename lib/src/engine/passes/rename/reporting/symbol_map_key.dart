import 'package:kernel/ast.dart';

/// Keys for the rename symbol map (obfuscated name → original name).
///
/// The key format is a rename-reporting concern: private names are qualified by
/// their library so distinct private symbols sharing text don't collide.
final class SymbolMapKey {
  const SymbolMapKey._();

  /// The symbol-map key for [name].
  static String forName(Name name) {
    final library = name.library;
    if (library == null) return name.text;
    return '${library.importUri}::${name.text}';
  }
}

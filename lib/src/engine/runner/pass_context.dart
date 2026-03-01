import 'package:kernel/kernel.dart';
import 'package:refractor/src/engine/name_generator.dart';
import 'package:refractor/src/engine/runner/pass_options.dart';
import 'package:refractor/src/engine/symbol_table.dart';

/// Shared mutable context passed to every obfuscation pass.
class PassContext {
  PassContext({
    required this.symbolTable,
    required this.nameGenerator,
    required this.options,
  });
  final SymbolTable symbolTable;
  final NameGenerator nameGenerator;
  final PassOptions options;

  /// Returns true if [library] belongs to user code that should be obfuscated.
  bool shouldObfuscateLibrary(Library library) {
    final uri = library.importUri;
    // Never touch SDK libraries.
    if (uri.scheme == 'dart') return false;
    // Apply package filter if set.
    if (options.packageFilter != null) {
      return uri.toString().contains(options.packageFilter!);
    }
    return true;
  }
}

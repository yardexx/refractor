import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/rename/declaration_collector.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/passes/rename/override_family/class_relation_index.dart';
import 'package:refractor/src/engine/passes/rename/override_family/override_family_analyzer.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';

/// Collects all declarations that should be renamed into a [RenameScope].
///
/// Orchestrates three sub-components:
///   1. [DeclarationCollector] — single AST walk for raw declarations
///   2. [ClassRelationIndex] — class hierarchy
///   3. [OverrideFamilyAnalyzer] — groups instance members into families
class RenameCollector {
  /// Collects declarations using ObfuscationTarget + RenamePassOptions.
  RenameScope collect(
    Component component,
    ObfuscationTarget target,
    RenamePassOptions options,
  ) {
    // 1. Walk AST, pick up raw declarations.
    final declarations = DeclarationCollector(target, options)
      ..collect(component);

    // 2. Build class hierarchy index.
    final hierarchy = ClassRelationIndex.build(
      declarations.classScopes.map((c) => c.node),
    );

    // 3. Group instance members into override families.
    final families = OverrideFamilyAnalyzer().analyze(
      declarations.classScopes,
      hierarchy,
    );

    return RenameScope(
      overrideFamilies: families,
      classScopes: declarations.classScopes,
      topLevelMembers: declarations.topLevelMembers,
      variables: declarations.variables,
    );
  }
}

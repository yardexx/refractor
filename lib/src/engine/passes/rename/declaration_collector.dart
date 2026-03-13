import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_scope.dart';
import 'package:refractor/src/engine/runner/obfuscation_target.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

/// Single AST walk that collects raw declarations for renaming.
///
/// Visits libraries, classes, members, and variables. Filters by
/// [ObfuscationTarget], `@pragma`, and `preserveMain`. Outputs raw
/// [ClassScope] list + top-level members + variables.
///
/// Knows nothing about override families or class hierarchy.
class DeclarationCollector extends RecursiveVisitor {
  DeclarationCollector(this._target, this._options);

  final ObfuscationTarget _target;
  final RenamePassOptions _options;

  final List<ClassScope> classScopes = [];
  final List<Member> topLevelMembers = [];
  final List<VariableDeclaration> variables = [];

  /// Collect all declarations from [component].
  void collect(Component component) {
    component.accept(this);
  }

  @override
  void visitLibrary(Library node) {
    if (!_target.shouldObfuscateLibrary(node)) return;

    // Collect top-level members.
    for (final proc in node.procedures) {
      if (_shouldSkipMember(proc)) continue;
      if (proc.name.text.isEmpty) continue;
      if (_options.preserveMain && proc.name.text == 'main') continue;
      topLevelMembers.add(proc);
    }
    for (final field in node.fields) {
      if (_shouldSkipMember(field)) continue;
      if (field.name.text.isEmpty) continue;
      topLevelMembers.add(field);
    }

    super.visitLibrary(node);
  }

  @override
  void visitClass(Class node) {
    if (!_target.shouldObfuscateLibrary(node.enclosingLibrary)) return;
    if (hasEntryPointPragma(node.annotations)) {
      // Still visit children for variables.
      super.visitClass(node);
      return;
    }

    final externalNames = _externalMemberNames(node);
    final instanceMembers = <Member>[];
    final staticMembers = <Member>[];
    final constructors = <Constructor>[];

    for (final proc in node.procedures) {
      if (_shouldSkipMember(proc)) continue;
      if (proc.name.text.isEmpty) continue;
      if (proc.isStatic) {
        staticMembers.add(proc);
      } else {
        if (externalNames.contains(proc.name.text)) continue;
        instanceMembers.add(proc);
      }
    }

    for (final field in node.fields) {
      if (_shouldSkipMember(field)) continue;
      if (field.name.text.isEmpty) continue;
      if (field.isStatic) {
        staticMembers.add(field);
      } else {
        if (externalNames.contains(field.name.text)) continue;
        instanceMembers.add(field);
      }
    }

    for (final ctor in node.constructors) {
      if (_shouldSkipMember(ctor)) continue;
      if (ctor.name.text.isEmpty) continue;
      constructors.add(ctor);
    }

    classScopes.add(
      ClassScope(
        node: node,
        instanceMembers: instanceMembers,
        staticMembers: staticMembers,
        constructors: constructors,
      ),
    );

    super.visitClass(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name;
    if (name != null && name.isNotEmpty) {
      variables.add(node);
    }
    super.visitVariableDeclaration(node);
  }

  bool _shouldSkipMember(Member member) {
    return hasEntryPointPragma(member.annotations);
  }

  /// Returns the set of instance member names declared in any external
  /// (non-obfuscatable) supertype of [cls].
  ///
  /// If a user class overrides a method from an SDK or third-party class
  /// (e.g. `toString`, `hashCode`, `build`), renaming it would break runtime
  /// dispatch. These names must be preserved.
  Set<String> _externalMemberNames(Class cls) {
    final names = <String>{};
    final visited = <Class>{};
    final stack = <Class>[];

    void addSupertypes(Class c) {
      if (c.supertype != null) stack.add(c.supertype!.classNode);
      for (final iface in c.implementedTypes) {
        stack.add(iface.classNode);
      }
      if (c.mixedInType != null) stack.add(c.mixedInType!.classNode);
    }

    addSupertypes(cls);

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) continue;

      if (!_target.shouldObfuscateLibrary(current.enclosingLibrary)) {
        for (final p in current.procedures) {
          if (!p.isStatic) names.add(p.name.text);
        }
        for (final f in current.fields) {
          if (!f.isStatic) names.add(f.name.text);
        }
      }

      addSupertypes(current);
    }

    return names;
  }
}

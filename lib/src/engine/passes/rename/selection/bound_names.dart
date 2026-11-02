import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/kernel_toolkit/relations/class_relations.dart';
import 'package:refractor/src/policy/obfuscation_scope.dart';

/// Instance member names that [cls] must keep because a declaration rename
/// will not touch also answers to them: members inherited from non-project
/// supertypes, members of kept project supertypes, and kept members (or every
/// member, when the class itself is kept) declared on [cls].
///
/// A project member with one of these names that shares an object with [cls]
/// — [cls] or one of its subtypes — must not be renamed, and no other member
/// of [cls] may be renamed *to* one of them, or it would override the fixed
/// member by accident.
Set<String> fixedInstanceNamesOf(Class cls, ObfuscationScope scope) {
  final names = <String>{};
  final classKept = !scope.shouldObfuscateClass(cls);
  for (final member in _instanceMembers(cls)) {
    if (classKept || !scope.shouldObfuscateMember(member)) {
      names.add(member.name.text);
    }
  }

  final visited = <Class>{};
  final stack = [...ClassRelations.directSupertypesOf(cls)];
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    if (!visited.add(current)) continue;

    final inProject = scope.isInProject(current.enclosingLibrary);
    final currentKept = inProject && !scope.shouldObfuscateClass(current);
    for (final member in _instanceMembers(current)) {
      if (!inProject || currentKept || !scope.shouldObfuscateMember(member)) {
        names.add(member.name.text);
      }
    }
    stack.addAll(ClassRelations.directSupertypesOf(current));
  }
  return names;
}

Iterable<Member> _instanceMembers(Class cls) => [
  for (final procedure in cls.procedures)
    if (!procedure.isStatic) procedure,
  for (final field in cls.fields)
    if (!field.isStatic) field,
];

/// Member selectors that some code refers to by spelling, in a way rename
/// cannot rewrite:
///
/// - dynamic gets, sets and invocations in libraries rename does not
///   transform (the SDK, dependencies, excluded and kept libraries);
/// - `#name` symbols and `Symbol('name')` anywhere, since `noSuchMethod`
///   handlers and `Function.apply` match them against member names at run
///   time.
///
/// Symbols inside compiler-generated `noSuchMethod` forwarders are skipped:
/// they only describe the forwarder's own (renamed) member.
Set<Name> collectSpelledSelectors(Component component, ObfuscationScope scope) {
  final collector = _SpelledSelectorCollector(scope);
  component.accept(collector);
  return collector.names;
}

class _SpelledSelectorCollector extends RecursiveVisitor {
  _SpelledSelectorCollector(this._scope);

  final ObfuscationScope _scope;
  final Set<Name> names = <Name>{};
  final Set<Constant> _seenConstants = <Constant>{};
  bool _rewritten = false;
  Library? _library;

  @override
  void visitLibrary(Library node) {
    _library = node;
    _rewritten = _scope.shouldObfuscateLibrary(node);
    super.visitLibrary(node);
  }

  @override
  void visitProcedure(Procedure node) {
    if (node.isNoSuchMethodForwarder) return;
    super.visitProcedure(node);
  }

  @override
  void visitDynamicGet(DynamicGet node) {
    if (!_rewritten) names.add(node.name);
    super.visitDynamicGet(node);
  }

  @override
  void visitDynamicSet(DynamicSet node) {
    if (!_rewritten) names.add(node.name);
    super.visitDynamicSet(node);
  }

  @override
  void visitDynamicInvocation(DynamicInvocation node) {
    if (!_rewritten) names.add(node.name);
    super.visitDynamicInvocation(node);
  }

  @override
  void visitSymbolLiteral(SymbolLiteral node) {
    final value = node.value;
    names.add(value.startsWith('_') ? Name(value, _library) : Name(value));
    super.visitSymbolLiteral(node);
  }

  @override
  void visitStaticInvocation(StaticInvocation node) {
    _addSymbolConstruction(node.target, node.arguments);
    super.visitStaticInvocation(node);
  }

  @override
  void visitConstructorInvocation(ConstructorInvocation node) {
    _addSymbolConstruction(node.target, node.arguments);
    super.visitConstructorInvocation(node);
  }

  @override
  void visitConstantExpression(ConstantExpression node) {
    _visitConstant(node.constant);
    super.visitConstantExpression(node);
  }

  void _addSymbolConstruction(Member target, Arguments arguments) {
    if (target.enclosingClass?.name != 'Symbol') return;
    if (!target.enclosingLibrary.importUri.isScheme('dart')) return;
    final first = arguments.positional.firstOrNull;
    // `Symbol('_x')` never matches a private member, so only public names.
    if (first is StringLiteral && !first.value.startsWith('_')) {
      names.add(Name(first.value));
    }
  }

  void _visitConstant(Constant constant) {
    if (!_seenConstants.add(constant)) return;
    switch (constant) {
      case SymbolConstant(:final name, :final libraryReference):
        names.add(
          libraryReference == null
              ? Name(name)
              : Name(name, libraryReference.asLibrary),
        );
      case ListConstant(:final entries):
      case SetConstant(:final entries):
        entries.forEach(_visitConstant);
      case MapConstant(:final entries):
        for (final entry in entries) {
          _visitConstant(entry.key);
          _visitConstant(entry.value);
        }
      case RecordConstant(:final positional, :final named):
        positional.forEach(_visitConstant);
        named.values.forEach(_visitConstant);
      case InstanceConstant(:final fieldValues):
        fieldValues.values.forEach(_visitConstant);
      default:
        break;
    }
  }
}

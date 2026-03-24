import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/obfuscation_target.dart';
import 'package:refractor/src/engine/passes/rename/model/rename_pass_options.dart';
import 'package:refractor/src/engine/policy/declaration_policy.dart';
import 'package:refractor/src/engine/policy/obfuscation_policy.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

class ObfuscationPolicyResolver {
  ObfuscationPolicy resolve(
    Component component,
    ObfuscationTarget target, {
    RenamePassOptions renameOptions = const RenamePassOptions(),
  }) {
    final libraryPolicies = <Library, DeclarationPolicy>{};
    final classPolicies = <Class, DeclarationPolicy>{};
    final memberPolicies = <Member, DeclarationPolicy>{};

    for (final library in component.libraries) {
      libraryPolicies[library] = target.shouldObfuscateLibrary(library)
          ? DeclarationPolicy.allow
          : const DeclarationPolicy(excludeFromAllObfuscation: true);
    }

    for (final library in component.libraries) {
      if (libraryPolicies[library]!.excludeFromAllObfuscation) continue;

      for (final cls in library.classes) {
        classPolicies[cls] = _policyFromAnnotations(cls.annotations);

        if (classPolicies[cls]!.isRenameExcluded) {
          continue;
        }

        final externalNames = _externalMemberNames(cls, target);
        for (final member in [...cls.procedures, ...cls.fields]) {
          final isStatic = switch (member) {
            Procedure() => member.isStatic,
            Field() => member.isStatic,
            _ => false,
          };
          if (isStatic) continue;
          if (!externalNames.contains(memberNameText(member))) continue;
          memberPolicies[member] = const DeclarationPolicy(
            excludeFromRename: true,
            excludeParametersFromRename: true,
          );
        }
      }

      for (final procedure in library.procedures) {
        final annotationPolicy = _policyFromAnnotations(procedure.annotations);
        final isMain =
            renameOptions.preserveMain && procedure.name.text == 'main';
        final mainPolicy = isMain
            ? const DeclarationPolicy(
                excludeFromRename: true,
                excludeParametersFromRename: true,
              )
            : DeclarationPolicy.allow;
        memberPolicies[procedure] = annotationPolicy.merge(mainPolicy);
      }

      for (final field in library.fields) {
        memberPolicies[field] = _policyFromAnnotations(field.annotations);
      }

      for (final cls in library.classes) {
        for (final procedure in cls.procedures) {
          final annotationPolicy = _policyFromAnnotations(
            procedure.annotations,
          );
          memberPolicies[procedure] =
              (memberPolicies[procedure] ?? DeclarationPolicy.allow).merge(
                annotationPolicy,
              );
        }
        for (final field in cls.fields) {
          final annotationPolicy = _policyFromAnnotations(field.annotations);
          memberPolicies[field] =
              (memberPolicies[field] ?? DeclarationPolicy.allow).merge(
                annotationPolicy,
              );
        }
        for (final constructor in cls.constructors) {
          memberPolicies[constructor] = _policyFromAnnotations(
            constructor.annotations,
          );
        }
      }
    }

    return ObfuscationPolicy(
      libraryPolicies: libraryPolicies,
      classPolicies: classPolicies,
      memberPolicies: memberPolicies,
    );
  }

  DeclarationPolicy _policyFromAnnotations(List<Expression> annotations) {
    if (hasEntryPointPragma(annotations)) {
      return const DeclarationPolicy(
        excludeFromRename: true,
        excludeParametersFromRename: true,
      );
    }
    return DeclarationPolicy.allow;
  }

  Set<String> _externalMemberNames(Class cls, ObfuscationTarget target) {
    final names = <String>{};
    final visited = <Class>{};
    final stack = <Class>[];

    void addSupertypes(Class current) {
      if (current.supertype != null) {
        stack.add(current.supertype!.classNode);
      }
      for (final iface in current.implementedTypes) {
        stack.add(iface.classNode);
      }
      if (current.mixedInType != null) {
        stack.add(current.mixedInType!.classNode);
      }
    }

    addSupertypes(cls);

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visited.add(current)) continue;

      if (!target.shouldObfuscateLibrary(current.enclosingLibrary)) {
        for (final procedure in current.procedures) {
          if (!procedure.isStatic) {
            names.add(procedure.name.text);
          }
        }
        for (final field in current.fields) {
          if (!field.isStatic) {
            names.add(field.name.text);
          }
        }
      }

      addSupertypes(current);
    }

    return names;
  }
}

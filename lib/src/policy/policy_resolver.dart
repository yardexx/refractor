import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/config/model/refractor_config.dart';
import 'package:refractor/src/policy/rename_policy_view.dart';
import 'package:refractor/src/policy/resolved_policy.dart';
import 'package:refractor/src/policy/string_encrypt_policy_view.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

final class PolicyResolver {
  ResolvedPolicy resolve({
    required Component component,
    required RefractorConfig config,
    required ProjectScope projectScope,
  }) {
    final renameConfig = _findConfig<RenamePassConfig>(config);
    final stringEncryptConfig = _findConfig<StringEncryptPassConfig>(config);

    final globalExcludes = config.excludePatterns;
    final renameExcludes = _compileGlobs(renameConfig?.exclude ?? const []);
    final stringExcludes = _compileGlobs(
      stringEncryptConfig?.exclude ?? const [],
    );

    final renameKeptLibraries = <Library>{};
    final renameKeptClasses = <Class>{};
    final renameExplicitMembers = <Member>{};
    final stringKeptLibraries = <Library>{};
    final stringKeptClasses = <Class>{};
    final stringExplicitMembers = <Member>{};

    for (final library in component.libraries) {
      final workspacePath = projectScope.workspacePathForLibrary(library);
      final globalKeep =
          workspacePath == null || _matchesAny(globalExcludes, workspacePath);
      final renameKeep =
          globalKeep || _matchesAny(renameExcludes, workspacePath);
      final stringKeep =
          globalKeep || _matchesAny(stringExcludes, workspacePath);

      if (renameKeep) {
        renameKeptLibraries.add(library);
      }
      if (stringKeep) {
        stringKeptLibraries.add(library);
      }

      _collectClassPolicies(
        library,
        renameKeptClasses,
        stringKeptClasses,
      );
      _collectTopLevelMemberPolicies(
        component,
        library,
        renameExplicitMembers,
        stringExplicitMembers,
      );
      _collectClassMemberPolicies(
        library,
        renameExplicitMembers,
        stringExplicitMembers,
      );
    }

    final renameMembers = _materializeMembers(
      component,
      keptLibraries: renameKeptLibraries,
      keptClasses: renameKeptClasses,
      explicitMembers: renameExplicitMembers,
    );
    final stringMembers = _materializeMembers(
      component,
      keptLibraries: stringKeptLibraries,
      keptClasses: stringKeptClasses,
      explicitMembers: stringExplicitMembers,
    );

    final renameClasses = _materializeClasses(
      component,
      keptLibraries: renameKeptLibraries,
      explicitClasses: renameKeptClasses,
    );
    final stringClasses = _materializeClasses(
      component,
      keptLibraries: stringKeptLibraries,
      explicitClasses: stringKeptClasses,
    );

    return ResolvedPolicy(
      rename: RenamePolicyView(
        keptLibraries: renameKeptLibraries,
        keptClasses: renameClasses,
        keptMembers: renameMembers,
      ),
      stringEncrypt: StringEncryptPolicyView(
        keptLibraries: stringKeptLibraries,
        keptClasses: stringClasses,
        keptMembers: stringMembers,
      ),
    );
  }

  T? _findConfig<T>(RefractorConfig config) {
    for (final passConfig in config.passes) {
      if (passConfig is T) {
        return passConfig as T;
      }
    }
    return null;
  }

  void _collectClassPolicies(
    Library library,
    Set<Class> renameKeptClasses,
    Set<Class> stringKeptClasses,
  ) {
    for (final cls in library.classes) {
      if (hasEntryPointPragma(cls.annotations)) {
        renameKeptClasses.add(cls);
      }
      // Future string-encrypt annotations plug in here.
      final _ = stringKeptClasses;
    }
  }

  void _collectTopLevelMemberPolicies(
    Component component,
    Library library,
    Set<Member> renameExplicitMembers,
    Set<Member> stringExplicitMembers,
  ) {
    final mainMethod = component.mainMethod;
    for (final procedure in library.procedures) {
      if (hasEntryPointPragma(procedure.annotations) ||
          identical(mainMethod, procedure)) {
        renameExplicitMembers.add(procedure);
      }
    }
    for (final field in library.fields) {
      if (hasEntryPointPragma(field.annotations)) {
        renameExplicitMembers.add(field);
      }
    }
    final _ = stringExplicitMembers;
  }

  void _collectClassMemberPolicies(
    Library library,
    Set<Member> renameExplicitMembers,
    Set<Member> stringExplicitMembers,
  ) {
    for (final cls in library.classes) {
      for (final procedure in cls.procedures) {
        if (hasEntryPointPragma(procedure.annotations)) {
          renameExplicitMembers.add(procedure);
        }
      }
      for (final field in cls.fields) {
        if (hasEntryPointPragma(field.annotations)) {
          renameExplicitMembers.add(field);
        }
      }
      for (final constructor in cls.constructors) {
        if (hasEntryPointPragma(constructor.annotations)) {
          renameExplicitMembers.add(constructor);
        }
      }
    }
    final _ = stringExplicitMembers;
  }

  Set<Class> _materializeClasses(
    Component component, {
    required Set<Library> keptLibraries,
    required Set<Class> explicitClasses,
  }) {
    final keptClasses = Set<Class>.from(explicitClasses);
    for (final library in component.libraries) {
      if (!keptLibraries.contains(library)) continue;
      keptClasses.addAll(library.classes);
    }
    return keptClasses;
  }

  Set<Member> _materializeMembers(
    Component component, {
    required Set<Library> keptLibraries,
    required Set<Class> keptClasses,
    required Set<Member> explicitMembers,
  }) {
    final keptMembers = Set<Member>.from(explicitMembers);
    for (final library in component.libraries) {
      if (keptLibraries.contains(library)) {
        keptMembers.addAll([
          ...library.procedures,
          ...library.fields,
          for (final cls in library.classes) ...[
            ...cls.procedures,
            ...cls.fields,
            ...cls.constructors,
          ],
        ]);
      }

      for (final cls in library.classes) {
        if (!keptClasses.contains(cls)) continue;
        keptMembers.addAll([
          ...cls.procedures,
          ...cls.fields,
          ...cls.constructors,
        ]);
      }
    }
    return keptMembers;
  }

  List<Glob> _compileGlobs(List<String> patterns) {
    return patterns.map(Glob.new).toList();
  }

  bool _matchesAny(List<Glob> globs, String? path) {
    if (path == null) return true;
    for (final glob in globs) {
      if (glob.matches(path)) {
        return true;
      }
    }
    return false;
  }
}

import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

/// Classes and members preserved by `@Refractor.keep()` annotations.
typedef AnnotationKeeps = ({Set<Class> classes, Set<Member> members});

/// Stateless scanners for each keep mechanism in `KeepSource`.
///
/// These are the shared, pass-agnostic building blocks the keep resolver
/// composes. Each only ever considers project libraries — external code is a
/// membership concern (`ProjectScope`), never a keep concern.

/// Project libraries whose workspace path matches any of [globs].
Set<Library> scanExcludedLibraries(
  Component component,
  ProjectScope projectScope,
  List<Glob> globs,
) {
  if (globs.isEmpty) return const {};
  final kept = <Library>{};
  for (final library in component.libraries) {
    final path = projectScope.workspacePathForLibrary(library);
    if (path == null) continue;
    if (globs.any((glob) => glob.matches(path))) {
      kept.add(library);
    }
  }
  return kept;
}

/// Classes and members carrying a `@Refractor.keep()` annotation.
AnnotationKeeps scanAnnotationKeeps(
  Component component,
  ProjectScope projectScope,
) {
  final classes = <Class>{};
  final members = <Member>{};
  for (final library in component.libraries) {
    if (projectScope.workspacePathForLibrary(library) == null) continue;

    for (final procedure in library.procedures) {
      if (hasRefractorKeepAnnotation(procedure.annotations)) {
        members.add(procedure);
      }
    }
    for (final field in library.fields) {
      if (hasRefractorKeepAnnotation(field.annotations)) members.add(field);
    }
    for (final cls in library.classes) {
      if (hasRefractorKeepAnnotation(cls.annotations)) classes.add(cls);
      for (final procedure in cls.procedures) {
        if (hasRefractorKeepAnnotation(procedure.annotations)) {
          members.add(procedure);
        }
      }
      for (final field in cls.fields) {
        if (hasRefractorKeepAnnotation(field.annotations)) members.add(field);
      }
      for (final constructor in cls.constructors) {
        if (hasRefractorKeepAnnotation(constructor.annotations)) {
          members.add(constructor);
        }
      }
    }
  }
  return (classes: classes, members: members);
}

/// The program entry point, if it lives in a project library.
Member? scanEntryPoint(Component component, ProjectScope projectScope) {
  final main = component.mainMethod;
  if (main == null) return null;
  if (!projectScope.containsLibrary(main.enclosingLibrary)) return null;
  return main;
}

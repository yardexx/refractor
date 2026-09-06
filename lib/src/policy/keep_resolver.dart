import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/policy/refractor_keep_annotation.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Classes and members preserved by `@Refractor.keep()` annotations.
typedef KeepAnnotations = ({Set<Class> classes, Set<Member> members});

/// Builds a [KeepPolicy] for a pass from the keep sources it declares.
///
/// Pass-agnostic: [resolve] is parameterized only by the declared
/// [KeepSource]s and the pass's own exclude globs — never by pass identity.
/// Each keep source is scanned only when the pass declares it.
///
/// Every scan only ever considers project libraries — external code is a
/// membership concern ([ProjectScope]), never a keep concern.
final class KeepResolver {
  KeepResolver({
    required Component component,
    required ProjectScope projectScope,
    required List<Glob> globalExcludes,
  }) : _component = component,
       _projectScope = projectScope,
       _globalExcludes = globalExcludes;

  final Component _component;
  final ProjectScope _projectScope;
  final List<Glob> _globalExcludes;

  /// The keep policy for a pass honoring [sources], whose own library excludes
  /// are [passExcludeGlobs] (combined with the global excludes).
  ///
  /// One branch per keep source: each contributes the declarations it protects.
  KeepPolicy resolve(Set<KeepSource> sources, List<String> passExcludeGlobs) {
    final keptLibraries = <Library>{};
    final keptClasses = <Class>{};
    final keptMembers = <Member>{};

    final hasExcludes = sources.contains(KeepSource.excludes);
    if (hasExcludes) {
      final excludedLibs = _findExcludedLibs(passExcludeGlobs);
      keptLibraries.addAll(excludedLibs);
    }

    final hasAnnotations = sources.contains(KeepSource.annotations);
    if (hasAnnotations) {
      final annotations = _findKeepAnnotations();
      keptClasses.addAll(annotations.classes);
      keptMembers.addAll(annotations.members);
    }

    final hasEntryPoint = sources.contains(KeepSource.entryPoint);
    if (hasEntryPoint) {
      final entryPoint = _scanEntryPoint();
      if (entryPoint != null) keptMembers.add(entryPoint);
    }

    return KeepPolicy(
      keptLibraries: keptLibraries,
      keptClasses: keptClasses,
      keptMembers: keptMembers,
    );
  }

  Set<Library> _findExcludedLibs(List<String> passExcludes) {
    final passExcludesGlobs = passExcludes.map(Glob.new);
    final allGlobs = [..._globalExcludes, ...passExcludesGlobs];
    if (allGlobs.isEmpty) return const {};

    final matched = <Library>{};
    final libs = _component.libraries;
    for (final lib in libs) {
      final path = _projectScope.workspacePathForLibrary(lib);

      if (path == null) continue;

      final hasMatch = allGlobs.any((glob) => glob.matches(path));
      if (hasMatch) matched.add(lib);
    }

    return matched;
  }

  KeepAnnotations _findKeepAnnotations() {
    final members = <Member>{};
    final classes = <Class>{};

    bool isKept(Annotatable node) {
      return RefractorKeepAnnotation.isPresentOn(node.annotations);
    }

    final libs = _component.libraries;
    for (final lib in libs) {
      if (!_projectScope.containsLibrary(lib)) continue;
      members.addAll(lib.members.where(isKept));

      for (final cls in lib.classes) {
        if (isKept(cls)) classes.add(cls);
        members.addAll(cls.members.where(isKept));
      }
    }

    return (classes: classes, members: members);
  }

  Member? _scanEntryPoint() {
    final main = _component.mainMethod;
    if (main == null) return null;
    if (!_projectScope.containsLibrary(main.enclosingLibrary)) return null;

    return main;
  }
}

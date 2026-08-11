import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/project/project_scope.dart';
import 'package:refractor/src/utils/rename_helpers.dart';

/// Classes and members preserved by `@Refractor.keep()` annotations.
typedef _AnnotationKeeps = ({Set<Class> classes, Set<Member> members});

/// Builds a [KeepPolicy] for a pass from the keep sources it declares.
///
/// Pass-agnostic: [resolve] is parameterized only by the declared
/// [KeepSource]s and the pass's own exclude globs — never by pass identity.
/// Uniform keeps (annotations, entry point) are scanned once and shared across
/// passes; exclude keeps depend on the pass's glob list and are scanned per
/// call.
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

  late final _AnnotationKeeps _annotations = _scanAnnotationKeeps();
  late final Member? _entryPoint = _scanEntryPoint();

  /// The keep policy for a pass honoring [sources], whose own library excludes
  /// are [passExcludeGlobs] (combined with the global excludes).
  KeepPolicy resolve(Set<KeepSource> sources, List<String> passExcludeGlobs) {
    return KeepPolicy(
      keptLibraries: sources.contains(KeepSource.excludes)
          ? _scanExcludedLibraries([
              ..._globalExcludes,
              ...passExcludeGlobs.map(Glob.new),
            ])
          : const {},
      keptClasses: sources.contains(KeepSource.annotations)
          ? _annotations.classes
          : const {},
      keptMembers: {
        if (sources.contains(KeepSource.annotations)) ..._annotations.members,
        if (sources.contains(KeepSource.entryPoint) && _entryPoint != null)
          _entryPoint,
      },
    );
  }

  /// Project libraries whose workspace path matches any of [globs].
  Set<Library> _scanExcludedLibraries(List<Glob> globs) {
    if (globs.isEmpty) return const {};
    final kept = <Library>{};
    for (final library in _component.libraries) {
      final path = _projectScope.workspacePathForLibrary(library);
      if (path == null) continue;
      if (globs.any((glob) => glob.matches(path))) {
        kept.add(library);
      }
    }
    return kept;
  }

  /// Classes and members carrying a `@Refractor.keep()` annotation.
  _AnnotationKeeps _scanAnnotationKeeps() {
    final classes = <Class>{};
    final members = <Member>{};

    void keepIfAnnotated(Member member) {
      if (hasRefractorKeepAnnotation(member.annotations)) members.add(member);
    }

    for (final library in _component.libraries) {
      if (!_projectScope.containsLibrary(library)) continue;
      library.members.forEach(keepIfAnnotated);
      for (final cls in library.classes) {
        if (hasRefractorKeepAnnotation(cls.annotations)) classes.add(cls);
        cls.members.forEach(keepIfAnnotated);
      }
    }
    return (classes: classes, members: members);
  }

  /// The program entry point, if it lives in a project library.
  Member? _scanEntryPoint() {
    final main = _component.mainMethod;
    if (main == null) return null;
    if (!_projectScope.containsLibrary(main.enclosingLibrary)) return null;
    return main;
  }
}

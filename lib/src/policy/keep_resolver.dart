import 'package:glob/glob.dart';
import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/policy/keep_scanners.dart';
import 'package:refractor/src/policy/keep_source.dart';
import 'package:refractor/src/project/project_scope.dart';

/// Builds a [KeepPolicy] for a pass from the keep sources it declares.
///
/// Pass-agnostic: [resolve] is parameterized only by the declared
/// [KeepSource]s and the pass's own exclude globs — never by pass identity.
/// Uniform keeps (annotations, entry point) are scanned once and shared across
/// passes; exclude keeps depend on the pass's glob list and are scanned per
/// call.
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

  late final AnnotationKeeps _annotations = scanAnnotationKeeps(
    _component,
    _projectScope,
  );
  late final Member? _entryPoint = scanEntryPoint(_component, _projectScope);

  /// The keep policy for a pass honoring [sources], whose own library excludes
  /// are [passExcludeGlobs] (combined with the global excludes).
  KeepPolicy resolve(Set<KeepSource> sources, List<String> passExcludeGlobs) {
    return KeepPolicy(
      keptLibraries: sources.contains(KeepSource.excludes)
          ? scanExcludedLibraries(_component, _projectScope, [
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
}

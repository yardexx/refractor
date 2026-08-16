import 'package:kernel/ast.dart';
import 'package:refractor/src/policy/keep_policy.dart';
import 'package:refractor/src/project/project_scope.dart';

/// The single authority a pass consults to decide whether it may transform a
/// node.
///
/// It combines the two orthogonal facts an obfuscation pass needs:
///   * **membership** — is the node part of the project being obfuscated?
///     (owned by [ProjectScope])
///   * **keep** — did the user/tooling ask to leave it alone?
///     (owned by [KeepPolicy])
///
/// A node is obfuscatable **iff it is in the project and not kept**. Every
/// selector and transformer asks this object rather than re-deriving the
/// decision from raw scope and policy, so the rule is enforced one way in one
/// place. The [project] and [keep] parts remain accessible for the rare cases
/// that must reason about an *external* node directly (e.g. detecting an
/// external supertype).
final class ObfuscationScope {
  const ObfuscationScope({
    required this.project,
    required this.keep,
  });

  /// Membership: whether a node belongs to the project being obfuscated.
  final ProjectScope project;

  /// Keep: declarations the user/tooling asked to preserve.
  final KeepPolicy keep;

  /// Whether [library] is part of the project (regardless of keep state).
  bool isInProject(Library library) => project.containsLibrary(library);

  bool shouldObfuscateLibrary(Library library) =>
      project.containsLibrary(library) && !keep.isLibraryKept(library);

  bool shouldObfuscateClass(Class cls) =>
      project.containsLibrary(cls.enclosingLibrary) && !keep.isClassKept(cls);

  bool shouldObfuscateMember(Member member) =>
      project.containsLibrary(member.enclosingLibrary) &&
      !keep.isMemberKept(member);
}

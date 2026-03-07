import 'package:kernel/ast.dart';
import 'package:refractor/src/engine/passes/pass_transformer.dart';

class RenameTransformer extends PassTransformer {
  RenameTransformer({
    required this.classRenames,
    required this.memberRenames,
    required this.variableRenames,
    required super.context,
  });

  /// Identity-based map: Class node -> new name string.
  final Map<Class, String> classRenames;

  /// Identity-based map: Member node -> new Name.
  /// Lookups use object identity, so they work even after the member's
  /// name has been mutated during traversal.
  final Map<Member, Name> memberRenames;
  final Map<VariableDeclaration, String> variableRenames;

  @override
  TreeNode visitClass(Class node) {
    final obf = classRenames[node];
    if (obf != null) node.name = obf;
    return super.visitClass(node);
  }

  @override
  TreeNode visitProcedure(Procedure node) {
    final newName = memberRenames[node];
    if (newName != null) node.name = newName;
    return super.visitProcedure(node);
  }

  @override
  TreeNode visitField(Field node) {
    final newName = memberRenames[node];
    if (newName != null) node.name = newName;
    return super.visitField(node);
  }

  @override
  TreeNode visitConstructor(Constructor node) {
    final newName = memberRenames[node];
    if (newName != null) node.name = newName;
    return super.visitConstructor(node);
  }

  @override
  TreeNode visitVariableDeclaration(VariableDeclaration node) {
    final newName = variableRenames[node];
    if (newName != null) node.name = newName;
    return super.visitVariableDeclaration(node);
  }

  // ---- Call site renames ----
  // These expression nodes carry a Name for member dispatch. When the target
  // member has been renamed, we must update the Name here too.

  @override
  TreeNode visitInstanceGet(InstanceGet node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGet(node);
  }

  @override
  TreeNode visitInstanceSet(InstanceSet node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceSet(node);
  }

  @override
  TreeNode visitInstanceInvocation(InstanceInvocation node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceInvocation(node);
  }

  @override
  TreeNode visitInstanceTearOff(InstanceTearOff node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceTearOff(node);
  }

  @override
  TreeNode visitInstanceGetterInvocation(InstanceGetterInvocation node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitInstanceGetterInvocation(node);
  }

  @override
  TreeNode visitSuperPropertyGet(SuperPropertyGet node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertyGet(node);
  }

  @override
  TreeNode visitSuperPropertySet(SuperPropertySet node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperPropertySet(node);
  }

  @override
  TreeNode visitSuperMethodInvocation(SuperMethodInvocation node) {
    final newName = memberRenames[node.interfaceTarget];
    if (newName != null) node.name = newName;
    return super.visitSuperMethodInvocation(node);
  }
}

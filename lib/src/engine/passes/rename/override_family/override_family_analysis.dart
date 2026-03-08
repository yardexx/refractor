import 'package:kernel/ast.dart';

/// Result of override family analysis.
class OverrideFamilyAnalysis {
  OverrideFamilyAnalysis({required this.familyOf});

  /// Maps each member to its override family ID.
  final Map<Member, int> familyOf;
}

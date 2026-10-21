/// Record of what happened to one `@virtualize`-annotated function.
final class VirtualizationRecord {
  const VirtualizationRecord({
    required this.functionName,
    required this.virtualized,
    this.opCount = 0,
    this.bytecodeLength = 0,
    this.stackDepth = 0,
    this.skipReason,
  });

  final String functionName;
  final bool virtualized;
  final int opCount;
  final int bytecodeLength;
  final int stackDepth;
  final String? skipReason;

  Map<String, Object?> toJson() => {
    'function': functionName,
    'virtualized': virtualized,
    if (virtualized) 'op_count': opCount,
    if (virtualized) 'bytecode_length': bytecodeLength,
    if (virtualized) 'stack_depth': stackDepth,
    if (skipReason != null) 'skip_reason': skipReason,
  };
}

/// Structured report emitted by a pass execution.
class PassReport {
  const PassReport({
    required this.passName,
    this.metadata = const {},
    this.message,
  });

  final String passName;
  final Map<String, String> metadata;
  final String? message;

  int get totalCount => metadata.values.fold(0, (sum, value) {
    return sum + (int.tryParse(value) ?? 0);
  });

  bool get isEmpty => metadata.isEmpty && message == null;

  Map<String, Object?> toJson() => {
    'pass_name': passName,
    'message': message,
    'metadata': metadata,
  };
}

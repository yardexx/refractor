/// Stable machine-readable metric emitted by a pass.
class PassMetric {
  const PassMetric({
    required this.key,
    required this.value,
  });

  final String key;
  final int value;
}

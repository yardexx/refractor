abstract base class PassConfig {
  const PassConfig({
    this.enabled = true,
    this.exclude = const [],
  });

  final bool enabled;
  final List<String> exclude;
}

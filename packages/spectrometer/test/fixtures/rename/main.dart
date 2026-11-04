// Every identifier under test is kept alive with `vm:never-inline`. Without
// it, the AOT compiler inlines or drops these small members and their names
// vanish from a plain build too, so their absence after obfuscation would
// prove nothing. The resistance band's control check enforces this.

class SecretAlgorithm {
  SecretAlgorithm(this._endpoint);

  final String _endpoint;

  // A getter rather than a public field: AOT never keeps plain field names,
  // so a field could not be checked in the binary at all.
  @pragma('vm:never-inline')
  String get apiEndpoint => _endpoint;

  @pragma('vm:never-inline')
  int computeProfitMargin(int revenue, int cost) =>
      revenue - cost + apiEndpoint.length;
}

class RevenueReporter {
  @pragma('vm:never-inline')
  String renderSummary(int margin) => 'margin:$margin';
}

@pragma('vm:never-inline')
void processConfidentialData() {
  final algorithm = SecretAlgorithm('https://rename.example.internal/v1');
  final margin = algorithm.computeProfitMargin(1000, 400);
  final reporter = RevenueReporter();
  print(reporter.renderSummary(margin));
}

void main() {
  processConfidentialData();
}

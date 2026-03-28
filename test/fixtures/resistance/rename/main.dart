class SecretAlgorithm {
  SecretAlgorithm(this.apiEndpoint);

  final String apiEndpoint;

  int computeProfitMargin(int revenue, int cost) => revenue - cost;
}

class RevenueReporter {
  String renderSummary(int margin) => 'margin:$margin';
}

void processConfidentialData() {
  final algorithm = SecretAlgorithm('https://rename.example.internal/v1');
  final margin = algorithm.computeProfitMargin(1000, 400);
  final reporter = RevenueReporter();
  print(reporter.renderSummary(margin));
}

void main() {
  processConfidentialData();
}

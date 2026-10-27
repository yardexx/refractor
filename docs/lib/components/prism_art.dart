/// The logo's prism as inline SVG, shared by the landing page playground and
/// the Rulebook comparisons.
///
/// Same proportions, outline weight, crossbar beam and spectrum angles as the
/// logo. The spectrum is split evenly into one band per entry in [bands]; each
/// entry is that band's `class` attribute, so CSS can color and light it.
String prismSvg(List<String> bands) {
  // Where the beam leaves the prism's right face, and where the spectrum
  // reaches the right edge of the viewBox.
  const exitX = 115.1, edgeX = 180.0;
  const exitTop = 115.7, exitBottom = 120.9;
  const edgeTop = 94.0, edgeBottom = 152.4;

  String f(double v) => v.toStringAsFixed(1);
  final n = bands.length;

  String band(int i) {
    double at(double from, double to, int k) => from + (to - from) * k / n;
    final s1 = at(exitTop, exitBottom, i), s2 = at(exitTop, exitBottom, i + 1);
    final e1 = at(edgeTop, edgeBottom, i), e2 = at(edgeTop, edgeBottom, i + 1);
    return '  <path class="${bands[i]}" d="M$exitX ${f(s1)}L$edgeX ${f(e1)}L$edgeX ${f(e2)}L$exitX ${f(s2)}Z"/>';
  }

  final paths = [for (var i = 0; i < n; i++) band(i)];

  return '''
<svg viewBox="0 0 180 210" aria-hidden="true">
  <defs>
    <linearGradient id="pg-beam" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="51.1" y2="0">
      <stop offset="0" stop-color="#fff" stop-opacity="0"/>
      <stop offset=".7" stop-color="#fff"/>
    </linearGradient>
  </defs>
  <path class="beam" d="M0 126.8L62.8 115.7L62.8 120.9L0 129.8Z" fill="url(#pg-beam)"/>
${paths.join('\n')}
  <path class="glass" d="M86 62L31.4 150L140.6 150ZM86 84.2L119.5 138.3L52.5 138.3Z" fill-rule="evenodd"/>
  <path class="glass" d="M66.4 115.7L105.6 115.7L108.7 120.9L63.3 120.9Z"/>
</svg>
''';
}

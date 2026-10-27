import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'highlight.dart';

/// The before/after card behind `<PassCompare>`: both snippets highlighted
/// and diffed, side by side.
class PassCompareCard extends StatelessComponent {
  const PassCompareCard({required this.pass, required this.before, required this.after, super.key});

  final String pass;
  final String before;
  final String after;

  @override
  Component build(BuildContext context) {
    final a = highlight(before, 'dart'), b = highlight(after, 'dart');
    _diff(a, b);
    return div(classes: 'pg pc pc-$pass', [
      div(classes: 'pg-stage', [
        _pane(
          [
            span(classes: 'pg-lights', [span([]), span([]), span([])]),
            span([Component.text('before')]),
          ],
          a,
          output: false,
        ),
        _pane(
          [
            span(classes: 'pc-dot', []),
            span([Component.text('after')]),
            span(classes: 'pg-tag', [Component.text('illustrative')]),
          ],
          b,
          output: true,
        ),
      ]),
    ]);
  }

  Component _pane(List<Component> head, List<CodeToken> tokens, {required bool output}) {
    final lines = <List<CodeToken>>[[]];
    for (final t in tokens) {
      if (t.kind == 'nl') {
        lines.add([]);
      } else {
        lines.last.add(t);
      }
    }
    return div(classes: 'pg-pane${output ? ' pg-out' : ''}', [
      div(classes: 'pg-pane-head', head),
      pre(classes: 'pg-code', [
        for (final line in lines)
          span(classes: 'pg-line', [
            for (final t in line)
              span(
                classes: ['tk-${t.kind}', if (t.changed) output ? 'fx' : 'gone'].join(' '),
                [Component.text(t.text)],
              ),
          ]),
      ]),
    ]);
  }
}

/// Marks the tokens of [a] and [b] outside their common subsequence (compared
/// on significant tokens), then lets whitespace between two changed tokens on
/// a line count as changed, so a rewritten span glows as one piece.
///
/// Names and literals weigh more than punctuation, so `sum(items)` against
/// `refractorCall(sum, [items])` keeps `sum` and marks the wrapper, rather
/// than keeping the `(`.
void _diff(List<CodeToken> a, List<CodeToken> b) {
  final x = a.where((t) => t.significant).toList(), y = b.where((t) => t.significant).toList();
  int weight(CodeToken t) => t.kind == 'p' ? 1 : 3;
  final best = List.generate(x.length + 1, (_) => List.filled(y.length + 1, 0));
  for (var i = x.length - 1; i >= 0; i--) {
    for (var j = y.length - 1; j >= 0; j--) {
      final skip = max(best[i + 1][j], best[i][j + 1]);
      best[i][j] = x[i].text == y[j].text ? max(skip, best[i + 1][j + 1] + weight(x[i])) : skip;
    }
  }
  for (final t in [...x, ...y]) {
    t.changed = true;
  }
  var i = 0, j = 0;
  while (i < x.length && j < y.length) {
    if (x[i].text == y[j].text && best[i][j] == best[i + 1][j + 1] + weight(x[i])) {
      x[i++].changed = false;
      y[j++].changed = false;
    } else if (best[i + 1][j] >= best[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  _fillGaps(x);
  _fillGaps(y);
  _bridgeWhitespace(a);
  _bridgeWhitespace(b);
}

/// A lone unchanged token between two changed ones on the same line belongs to
/// the rewrite; it only matched the original by coincidence (the `+` inside
/// `(a ^ b) + ((a & b) << 1)`, say). Not between two names, though: in
/// `final e = b` after a rename, the `=` really is unchanged.
void _fillGaps(List<CodeToken> seq) {
  bool isName(CodeToken t) => const {'id', 'ty', 'fn'}.contains(t.kind);
  for (var k = 1; k + 1 < seq.length; k++) {
    final prev = seq[k - 1], t = seq[k], next = seq[k + 1];
    if (t.changed || !prev.changed || !next.changed || (isName(prev) && isName(next))) continue;
    if (prev.line == t.line && t.line == next.line) t.changed = true;
  }
}

void _bridgeWhitespace(List<CodeToken> tokens) {
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].kind != 'ws') continue;
    final prev = i > 0 ? tokens[i - 1] : null, next = i + 1 < tokens.length ? tokens[i + 1] : null;
    tokens[i].changed = (prev?.changed ?? false) && (next?.changed ?? false) && prev!.significant && next!.significant;
  }
}

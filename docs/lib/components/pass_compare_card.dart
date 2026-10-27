import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../rulebook/passes.dart';

/// The before/after card behind `<PassCompare>`: both snippets highlighted
/// and diffed, with a switch that turns the pass off (the "after" pane shows
/// the original) and back on, replaying the glow.
@client
class PassCompareCard extends StatefulComponent {
  const PassCompareCard({required this.pass, required this.before, required this.after, super.key});

  final String pass;
  final String before;
  final String after;

  @override
  State<PassCompareCard> createState() => _PassCompareCardState();
}

class _PassCompareCardState extends State<PassCompareCard> {
  bool _applied = true;
  late final List<_Token> _before, _after, _original;

  @override
  void initState() {
    super.initState();
    _before = _tokenize(component.before);
    _after = _tokenize(component.after);
    _diff(_before, _after);
    // Unmarked, for the "after" pane while the pass is switched off.
    _original = _tokenize(component.before);
  }

  @override
  Component build(BuildContext context) {
    final title = passBySlug(component.pass).title;
    return div(classes: 'pg pc pc-${component.pass}${_applied ? '' : ' pc-off'}', [
      div(classes: 'pg-stage', [
        _pane(
          [
            span(classes: 'pg-lights', [span([]), span([]), span([])]),
            span([Component.text('before')]),
          ],
          _applied ? _before : _original,
          output: false,
        ),
        _pane(
          [
            span(classes: 'pc-dot', []),
            span([Component.text('after')]),
            span(classes: 'pg-tag', [Component.text('illustrative')]),
            button(
              classes: 'pc-switch',
              attributes: {
                'role': 'switch',
                'aria-checked': '$_applied',
                'aria-label': 'Apply $title',
                'title': _applied ? 'Turn $title off' : 'Apply $title',
              },
              onClick: () => setState(() => _applied = !_applied),
              [span(classes: 'pc-knob', [])],
            ),
          ],
          _applied ? _after : _original,
          output: true,
        ),
      ]),
    ]);
  }

  Component _pane(List<Component> head, List<_Token> tokens, {required bool output}) {
    final lines = <List<_Token>>[[]];
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

class _Token {
  _Token(this.text, this.kind);

  final String text;

  /// Syntax class (`kw`, `ty`, `id`, `fn`, `str`, `num`, `lbl`, `cm`, `p`), or
  /// `ws` / `nl` for whitespace.
  String kind;

  bool changed = false;

  /// Zero-based source line.
  int line = 0;

  bool get significant => kind != 'ws' && kind != 'nl';
}

final _tokenPattern = RegExp(
  r'''(//[^\n]*)|('(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*")|(0x[0-9a-fA-F]+|\d+(?:\.\d+)?)|([A-Za-z_$][\w$]*)|(\n)|([ \t]+)|(.)''',
);

const _keywords = {
  'as', 'case', 'class', 'const', 'continue', 'else', 'final', 'if', 'late', //
  'new', 'null', 'return', 'switch', 'this', 'true', 'false', 'var', 'void',
};
const _builtinTypes = {'int', 'double', 'num', 'bool', 'dynamic'};

/// A small Dart highlighter: enough for the Rulebook's snippets.
List<_Token> _tokenize(String source) {
  final tokens = [
    for (final m in _tokenPattern.allMatches(source))
      if (m[1] != null)
        _Token(m[1]!, 'cm')
      else if (m[2] != null)
        _Token(m[2]!, 'str')
      else if (m[3] != null)
        _Token(m[3]!, 'num')
      else if (m[4] != null)
        _Token(m[4]!, 'id')
      else if (m[5] != null)
        _Token(m[5]!, 'nl')
      else if (m[6] != null)
        _Token(m[6]!, 'ws')
      else
        _Token(m[7]!, 'p'),
  ];

  var line = 0;
  for (final t in tokens) {
    t.line = line;
    if (t.kind == 'nl') line++;
  }

  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != 'id') continue;
    final next = tokens.skip(i + 1).where((n) => n.kind != 'ws').firstOrNull;
    t.kind = switch (t.text) {
      _ when _keywords.contains(t.text) => 'kw',
      _ when RegExp(r'^L\d+$').hasMatch(t.text) => 'lbl',
      _ when _builtinTypes.contains(t.text) || t.text.startsWith(RegExp('[A-Z]')) => 'ty',
      _ when next?.text == '(' => 'fn',
      _ => 'id',
    };
  }
  return tokens;
}

/// Marks the tokens of [a] and [b] outside their common subsequence (compared
/// on significant tokens), then lets whitespace between two changed tokens on
/// a line count as changed, so a rewritten span glows as one piece.
///
/// Names and literals weigh more than punctuation, so `sum(items)` against
/// `refractorCall(sum, [items])` keeps `sum` and marks the wrapper, rather
/// than keeping the `(`.
void _diff(List<_Token> a, List<_Token> b) {
  final x = a.where((t) => t.significant).toList(), y = b.where((t) => t.significant).toList();
  int weight(_Token t) => t.kind == 'p' ? 1 : 3;
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
void _fillGaps(List<_Token> seq) {
  bool isName(_Token t) => const {'id', 'ty', 'fn'}.contains(t.kind);
  for (var k = 1; k + 1 < seq.length; k++) {
    final prev = seq[k - 1], t = seq[k], next = seq[k + 1];
    if (t.changed || !prev.changed || !next.changed || (isName(prev) && isName(next))) continue;
    if (prev.line == t.line && t.line == next.line) t.changed = true;
  }
}

void _bridgeWhitespace(List<_Token> tokens) {
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].kind != 'ws') continue;
    final prev = i > 0 ? tokens[i - 1] : null, next = i + 1 < tokens.length ? tokens[i + 1] : null;
    tokens[i].changed = (prev?.changed ?? false) && (next?.changed ?? false) && prev!.significant && next!.significant;
  }
}

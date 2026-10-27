import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

/// A side-by-side before/after comparison in the landing page's code card.
///
/// In markdown, wrap two fenced code blocks (before, then after):
///
/// ````md
/// <PassCompare pass="rename">
///
/// ```dart
/// class PaymentProcessor {}
/// ```
///
/// ```dart
/// class a {}
/// ```
///
/// </PassCompare>
/// ````
///
/// Both snippets are syntax-highlighted and diffed token by token: what the
/// pass changed glows in its color in the "after" pane, and what it replaced
/// is marked in the "before" pane. `pass` picks the color (`pc-<pass>` in
/// `web/styles/code-card.css`).
class PassCompare extends CustomComponent {
  PassCompare() : super.base();

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(tag: 'PassCompare', :final attributes, :final children?)) {
      final blocks = children.expand(_codeBlocks).toList();
      if (blocks.length != 2) {
        throw ArgumentError('<PassCompare> needs two code blocks (before, after); found ${blocks.length}.');
      }
      return _PassCompareCard(pass: attributes['pass'] ?? '', before: blocks[0], after: blocks[1]);
    }
    return null;
  }

  static Iterable<String> _codeBlocks(Node node) sync* {
    if (node case ElementNode(tag: 'pre', :final children?)) {
      yield children.map((c) => c.innerText).join().trimRight();
    } else if (node case ElementNode(:final children?)) {
      for (final child in children) {
        yield* _codeBlocks(child);
      }
    }
  }
}

class _PassCompareCard extends StatelessComponent {
  const _PassCompareCard({required this.pass, required this.before, required this.after});

  final String pass;
  final String before;
  final String after;

  @override
  Component build(BuildContext context) {
    final a = _tokenize(before), b = _tokenize(after);
    _diff(a, b);

    return Component.fragment([
      Document.head(
        children: [link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css')],
      ),
      div(classes: 'pg pc pc-$pass', [
        div(classes: 'pg-stage', [
          _pane('before', a, output: false),
          _pane('after', b, output: true),
        ]),
      ]),
    ]);
  }

  Component _pane(String label, List<_Token> tokens, {required bool output}) {
    final lines = <List<_Token>>[[]];
    for (final t in tokens) {
      if (t.kind == 'nl') {
        lines.add([]);
      } else {
        lines.last.add(t);
      }
    }
    return div(classes: 'pg-pane${output ? ' pg-out' : ''}', [
      div(classes: 'pg-pane-head', [
        if (output) span(classes: 'pc-dot', []) else span(classes: 'pg-lights', [span([]), span([]), span([])]),
        span([Component.text(label)]),
        if (output) span(classes: 'pg-tag', [Component.text('illustrative')]),
      ]),
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

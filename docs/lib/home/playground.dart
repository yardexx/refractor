import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/prism_art.dart';

/// The passes the playground can toggle, in the order Refractor runs them.
enum DemoPass {
  rename('Rename', 'rename'),
  strings('Strings', 'strings'),
  ints('Integers', 'ints'),
  arithmetic('Arithmetic', 'arith'),
  flatten('Flatten', 'flatten'),
  deadCode('Dead code', 'dead')
  ;

  const DemoPass(this.label, this.slug);

  final String label;

  /// CSS hook shared by the chip, the prism ray and the tokens it changes.
  final String slug;
}

/// An interactive before/after view of one class going through the passes.
///
/// The output is hand-modelled Dart that mirrors what each pass does to the
/// kernel; it is not produced by running Refractor.
@client
class Playground extends StatefulComponent {
  const Playground({super.key});

  @override
  State createState() => _PlaygroundState();
}

class _PlaygroundState extends State<Playground> {
  Set<DemoPass> _on = {};
  String? _hover;
  Timer? _autoplay;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _startAutoplay();
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    super.dispose();
  }

  /// Switches the passes on one at a time, so a first-time visitor sees each
  /// transform land separately.
  void _startAutoplay() {
    _autoplay?.cancel();
    var next = 0;
    _autoplay = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (next >= DemoPass.values.length) {
        timer.cancel();
        return;
      }
      setState(() => _on = {..._on, DemoPass.values[next++]});
    });
  }

  void _replay() {
    setState(() => _on = {});
    _startAutoplay();
  }

  void _toggle(DemoPass pass) {
    _autoplay?.cancel();
    setState(() {
      _on = _on.contains(pass) ? ({..._on}..remove(pass)) : {..._on, pass};
    });
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: ['pg', for (final pass in _on) 'on-${pass.slug}'].join(' '),
      [
        div(classes: 'pg-toolbar', [
          span(classes: 'pg-label', [Component.text('Passes')]),
          div(classes: 'pg-chips', [
            for (final pass in DemoPass.values)
              button(
                classes: 'pg-chip chip-${pass.slug}',
                attributes: {'aria-pressed': '${_on.contains(pass)}'},
                onClick: () => _toggle(pass),
                [
                  span(classes: 'pg-dot', []),
                  Component.text(pass.label),
                ],
              ),
          ]),
          button(classes: 'pg-replay', onClick: _replay, [
            Component.text('↻ Replay'),
          ]),
        ]),
        div(classes: 'pg-stage', [
          _pane('lib/payment.dart', _render(const {}), output: false),
          div(classes: 'pg-prism', [RawText(_prismSvg)]),
          _pane('build/out', _render(_on), output: true),
        ]),
        div(classes: 'pg-status', [
          span(classes: 'pg-lookup', [Component.text(_lookupText())]),
          span(classes: 'pg-report', [Component.text(_reportText())]),
        ]),
      ],
    );
  }

  Component _pane(String file, List<_Line> lines, {required bool output}) {
    return div(classes: 'pg-pane${output ? ' pg-out' : ''}', [
      div(classes: 'pg-pane-head', [
        span(classes: 'pg-lights', [span([]), span([]), span([])]),
        span([Component.text(file)]),
        if (output) span(classes: 'pg-tag', [Component.text('as Dart, illustrative')]),
      ]),
      pre(classes: 'pg-code', [
        for (final line in lines)
          span(classes: 'pg-line', [
            for (final (i, tok) in line.indexed) _token(i, tok),
          ]),
      ]),
    ]);
  }

  Component _token(int index, _Tok tok) {
    final symbol = tok.symbol;
    return span(
      key: ValueKey('$index:${tok.text}'),
      classes: [
        'tk-${tok.kind}',
        if (tok.pass case final pass?) 'fx fx-${pass.slug}',
        if (symbol != null) 'sym',
        if (symbol != null && symbol == _hover) 'hl',
      ].join(' '),
      events: symbol == null
          ? null
          : {
              'mouseenter': (_) => setState(() => _hover = symbol),
              'mouseleave': (_) => setState(() => _hover = null),
            },
      [Component.text(tok.text)],
    );
  }

  String _lookupText() {
    final symbol = _hover;
    if (symbol == null) return 'Hover a name to look it up in the symbol map.';
    if (!_on.contains(DemoPass.rename)) return '$symbol is not renamed yet. Turn on Rename.';
    return '${_renames[symbol]}  ←  $symbol';
  }

  String _reportText() {
    if (_on.isEmpty) return 'No passes enabled';
    final counts = {
      DemoPass.rename: '8 names',
      DemoPass.strings: '1 string',
      DemoPass.ints: '1 integer',
      DemoPass.arithmetic: '2 expressions',
      DemoPass.flatten: '1 function',
      DemoPass.deadCode: '1 block',
    };
    return '✓ ${[for (final pass in DemoPass.values)
      if (_on.contains(pass)) counts[pass]!].join(' · ')}';
  }
}

/// One highlighted run of text in a code pane.
class _Tok {
  const _Tok(this.text, {this.kind = 'p', this.symbol, this.pass});

  final String text;

  /// Syntax class: `kw`, `ty`, `id`, `fn`, `str`, `num`, `lbl` or `p`.
  final String kind;

  /// The original identifier this token stands for, for cross-highlighting.
  final String? symbol;

  /// The pass that produced this token, if any.
  final DemoPass? pass;
}

typedef _Line = List<_Tok>;

const _renames = {
  'PaymentProcessor': 'a',
  'endpoint': 'b',
  'chargeCard': 'c',
  'amount': 'd',
  'tax': 'e',
  'total': 'f',
  'fee': 'g',
  'send': 'h',
  'refractorDecode': 'i',
  'refractorDecodeInt': 'j',
};

/// Renders the sample class with the given passes applied.
List<_Line> _render(Set<DemoPass> on) {
  final rename = on.contains(DemoPass.rename);

  _Tok kw(String text, [DemoPass? pass]) => _Tok(text, kind: 'kw', pass: pass);
  _Tok ty(String text) => _Tok(text, kind: 'ty');
  _Tok pu(String text, [DemoPass? pass]) => _Tok(text, pass: pass);
  _Tok lit(String text, [DemoPass? pass]) => _Tok(text, kind: 'num', pass: pass);
  _Tok id(String name, {String kind = 'id', DemoPass? pass}) => _Tok(
    rename ? _renames[name]! : name,
    kind: kind,
    symbol: name,
    pass: rename ? DemoPass.rename : pass,
  );

  List<_Tok> str(String value) {
    const s = DemoPass.strings;
    if (!on.contains(s)) return [_Tok("'$value'", kind: 'str')];
    return [
      id('refractorDecode', kind: 'fn', pass: s),
      pu('([', s),
      lit('0x2e, 0x91, 0x07, 0xc4, …', s),
      pu('], ', s),
      lit('0x5a3c91e7', s),
      pu(')', s),
    ];
  }

  List<_Tok> intLit(int value, String key, String encoded) {
    const n = DemoPass.ints;
    if (!on.contains(n)) return [lit('$value')];
    return [
      id('refractorDecodeInt', kind: 'fn', pass: n),
      pu('(', n),
      lit(key, n),
      pu(', ', n),
      lit(encoded, n),
      pu(')', n),
    ];
  }

  List<_Tok> add(String a, String b) {
    const m = DemoPass.arithmetic;
    if (!on.contains(m)) return [id(a), pu(' + '), id(b)];
    return [
      pu('(', m), id(a), pu(' ^ ', m), id(b), pu(') + ((', m), //
      id(a), pu(' & ', m), id(b), pu(') << ', m), lit('1', m), pu(')', m),
    ];
  }

  // The method body as statements, so flattening can re-thread them.
  final body = <({String? local, List<_Tok> code})>[
    (local: 'total', code: add('amount', 'tax')),
    (local: 'fee', code: [id('total'), pu(' ~/ '), ...intLit(40, '0x2b9e0c55', '0x2b9e0c7d')]),
    (
      local: null,
      code: [
        id('send', kind: 'fn'),
        pu('('),
        id('endpoint'),
        pu(', '),
        ...add('total', 'fee'),
        pu(')'),
      ],
    ),
    (local: null, code: [kw('return'), pu(' '), id('fee')]),
  ];

  const indent = '    ';
  final lines = <_Line>[
    [kw('class'), pu(' '), id('PaymentProcessor', kind: 'ty'), pu(' {')],
    [pu('  '), kw('final'), pu(' '), id('endpoint'), pu(' = '), ...str('https://pay.acme.dev/v2'), pu(';')],
    [],
    [
      pu('  '),
      ty('int'),
      pu(' '),
      id('chargeCard', kind: 'fn'),
      pu('('),
      ty('int'),
      pu(' '),
      id('amount'),
      pu(', '),
      ty('int'),
      pu(' '),
      id('tax'),
      pu(') {'),
    ],
  ];

  if (on.contains(DemoPass.deadCode)) {
    const d = DemoPass.deadCode;
    final guard = [pu('(', d), id('amount', pass: d), pu(' & ', d), lit('0xFFFF', d), pu(')', d)];
    lines.addAll([
      [pu(indent), kw('if', d), pu(' (', d), ...guard, pu(' * ', d), ...guard, pu(' < ', d), lit('0', d), pu(') {', d)],
      [pu('$indent  '), id('amount', pass: d), pu(' + ', d), lit('40503', d), pu(';', d)],
      [pu('$indent  '), id('amount', pass: d), pu(' * ', d), lit('12789', d), pu(';', d)],
      [pu(indent), pu('}', d)],
    ]);
  }

  if (on.contains(DemoPass.flatten)) {
    // Statement i becomes case caseOf[i]; cases are listed in numeric order,
    // so the real sequence is only visible by following the continues.
    const f = DemoPass.flatten;
    const caseOf = [2, 0, 3, 1];
    _Tok label(int n) => _Tok('L$n', kind: 'lbl', pass: f);

    _Line caseLine(int c) {
      final i = caseOf.indexOf(c);
      final stmt = body[i];
      return [
        pu('$indent  '),
        label(c),
        pu(': ', f),
        kw('case', f),
        pu(' ', f),
        lit('$c', f),
        pu(': ', f),
        if (stmt.local case final local?) ...[id(local), pu(' = ')],
        ...stmt.code,
        pu(';'),
        if (i + 1 < body.length) ...[pu(' ', f), kw('continue', f), pu(' ', f), label(caseOf[i + 1]), pu(';', f)],
      ];
    }

    lines.addAll([
      [
        pu(indent),
        kw('late', f),
        pu(' ', f),
        ty('int'),
        pu(' ', f),
        id('total', pass: f),
        pu(', ', f),
        id('fee', pass: f),
        pu(';', f),
      ],
      [pu(indent), kw('switch', f), pu(' (', f), lit('${caseOf.first}', f), pu(') {', f)],
      for (var c = 0; c < caseOf.length; c++) caseLine(c),
      [pu(indent), pu('}', f)],
    ]);
  } else {
    for (final stmt in body) {
      lines.add([
        pu(indent),
        if (stmt.local case final local?) ...[kw('final'), pu(' '), id(local), pu(' = ')],
        ...stmt.code,
        pu(';'),
      ]);
    }
  }

  lines.addAll([
    [pu('  }')],
    [pu('}')],
  ]);
  return lines;
}

/// The logo's prism with one band per pass; bands light up via the
/// `on-<slug>` classes on the playground root.
final _prismSvg = prismSvg([for (final pass in DemoPass.values) 'ray ray-${pass.slug}']);

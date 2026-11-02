import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../diagrams/autoplay.dart';

/// A short animation in a pass page's "What it does" that shows what the pass
/// does, without words or controls beyond a pause button: the page around it
/// does the explaining. It loops through its steps like the Architecture
/// diagrams ([Autoplay]). Readers who prefer reduced motion get one still
/// step that shows the pass's effect.
///
/// Each step is a class on the stage (`pa-step-<n>`), and CSS transitions
/// carry the parts from one step to the next (`web/styles/pass-animation.css`).
/// Three kinds of stage are shared between passes: labelled tiles (the two
/// encryption passes), code rows that move, change and get walked (most
/// passes), and a small call graph (call indirection). Flattening has its own.
@client
class PassAnimation extends StatefulComponent {
  const PassAnimation({required this.pass, super.key});

  /// A pass slug with a story below.
  final String pass;

  @override
  State<PassAnimation> createState() => _PassAnimationState();
}

/// A story: what the animation shows, for screen readers; its stage at each
/// step; and the step to hold still on when motion is reduced.
typedef _Story = ({String label, int steps, int still, Component Function(int step) stage});

class _PassAnimationState extends State<PassAnimation> with Autoplay<PassAnimation> {
  late final _Story _story = switch (component.pass) {
    'rename' => _rename,
    'strings' => _strings,
    'ints' => _ints,
    'arith' => _arith,
    'opaque' => _opaque,
    'flatten' => _flatten,
    'dead' => _dead,
    'bogus' => _bogus,
    'call' => _call,
    final other => throw ArgumentError('No animation for pass "$other".'),
  };

  @override
  int get stepCount => _story.steps;

  @override
  Duration get interval => const Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    // Autoplay doesn't start the tour when motion is reduced; hold the step
    // that shows the effect instead of the untouched code.
    if (kIsWeb && !playing) step = _story.still;
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'dg pa pc-${component.pass}', [
      div(
        classes: 'pa-stage pa-step-$step',
        attributes: {'role': 'img', 'aria-label': _story.label},
        [_story.stage(step)],
      ),
      button(
        classes: 'pa-pause',
        attributes: {'aria-label': playing ? 'Pause the animation' : 'Play the animation'},
        onClick: togglePlay,
        [Component.text(playing ? '❚❚' : '▶')],
      ),
    ]);
  }
}

String _hex(int value, {int width = 2}) => '0x${value.toRadixString(16).padLeft(width, '0')}';

// Labelled tiles, for the encryption passes. Each tile grows a row per step
// (0 text, 1 plain value, 2 key, 3 result), then shrinks back to one row in
// which the result has taken the text's place: what ships (4).

/// A tile: the text, its plain value, the key, the result as a value, and the
/// result as it reads in place of the text.
typedef _Tile = ({String text, String key, String plain, String result, String stored});

/// A row that opens and closes by animating its height (`pas-fold-<name>`).
Component _fold(String name, List<Component> children) => div(classes: 'pas-fold pas-fold-$name', [
  div(classes: 'pas-fold-in', children),
]);

Component _tiles(List<_Tile> tiles, {required ({String text, String plain}) labels}) => div(classes: 'pas', [
  div(classes: 'pas-tiles', [
    div(classes: 'pas-labels', [
      span(classes: 'pas-top', [
        span(classes: 'pas-label pas-top-text', [Component.text(labels.text)]),
        span(classes: 'pas-label pas-top-result', [Component.text('Result')]),
      ]),
      _fold('plain', [
        span(classes: 'pas-label', [Component.text(labels.plain)]),
      ]),
      _fold('key', [
        span(classes: 'pas-label', [Component.text('Key')]),
      ]),
      _fold('result', [
        span(classes: 'pas-label', [Component.text('Result')]),
      ]),
    ]),
    for (final (i, t) in tiles.indexed)
      div(classes: 'pas-tile', styles: Styles(raw: {'--i': '$i'}), [
        span(classes: 'pas-top', [
          span(classes: 'pas-char', [Component.text(t.text)]),
          span(classes: 'pas-top-result', [Component.text(t.stored)]),
        ]),
        _fold('plain', [
          span(classes: 'pas-byte', [Component.text(t.plain)]),
        ]),
        _fold('key', [
          span(classes: 'pas-key', [
            span(classes: 'pas-op', [Component.text('⊕ ')]),
            Component.text(t.key),
          ]),
        ]),
        _fold('result', [
          span(classes: 'pas-enc', [Component.text(t.result)]),
        ]),
      ]),
  ]),
]);

const _word = 'Welcome';
// Chosen so every result is a printable character: Welcome becomes fxSM^pZ.
const _key = [0x31, 0x1d, 0x3f, 0x2e];

final _Story _strings = (
  label:
      'Each letter of Welcome shows its byte, then a key, then the XOR of the two; '
      'then the result takes the letter\'s place, which is what the binary stores.',
  steps: 5,
  still: 3,
  stage: (step) => _tiles(
    [
      for (final (i, unit) in _word.codeUnits.indexed)
        (
          text: String.fromCharCode(unit),
          key: _hex(_key[i % _key.length]),
          plain: _hex(unit),
          result: _hex(unit ^ _key[i % _key.length]),
          stored: String.fromCharCode(unit ^ _key[i % _key.length]),
        ),
    ],
    labels: (text: 'Text', plain: 'Bytes'),
  ),
);

// The integer from the Rulebook example, and its key.
const _int = 30000, _intKey = 0x6c21a9f3;

final _Story _ints = (
  label:
      'The number 30000 shows its hex value, then a key, then the XOR of the two; '
      'then the result takes the number\'s place, which is what the binary stores.',
  steps: 5,
  still: 3,
  stage: (step) => _tiles(
    [
      (
        text: '$_int',
        key: _hex(_intKey, width: 8),
        plain: _hex(_int, width: 4),
        result: _hex(_int ^ _intKey, width: 8),
        stored: '${_int ^ _intKey}',
      ),
    ],
    labels: (text: 'Value', plain: 'Hex'),
  ),
);

// Code rows: lines of code that can move (pos), indent, appear or disappear
// (a null text), and change text from step to step. In a walk step, a
// highlight visits the rows that have a walk index, in that order, and the
// rows marked `skip` fade back. A line starting with `!` is wholly new (in
// the pass's color); inside a line, `{x:…}` is what the pass produced or
// touches, `{m:…}` is muted and `{k:…}` is kept as it was.

typedef _Row = ({List<String?> text, List<int> pos, List<int> indent, int? walk, bool skip});

_Row _row(List<String?> text, List<int> pos, {List<int> indent = const [0], int? walk, bool skip = false}) =>
    (text: text, pos: pos, indent: indent, walk: walk, skip: skip);

T _at<T>(List<T> perStep, int step) => perStep[step < perStep.length ? step : perStep.length - 1];

final _token = RegExp(r'\{([xmk]):([^}]*)\}');

List<Component> _line(String markup) {
  final parts = <Component>[];
  var at = 0;
  for (final m in _token.allMatches(markup)) {
    if (m.start > at) parts.add(Component.text(markup.substring(at, m.start)));
    parts.add(span(key: ValueKey('${m.start}:${m[1]}:${m[2]}'), classes: 'pa-${m[1]}', [Component.text(m[2]!)]));
    at = m.end;
  }
  if (at < markup.length) parts.add(Component.text(markup.substring(at)));
  return parts;
}

Component _rows(int step, List<_Row> rows, {Set<int> walkSteps = const {}}) {
  final height = [for (final r in rows) _at(r.pos, step)].reduce((x, y) => x > y ? x : y) + 1;
  return div(classes: ['par', if (walkSteps.contains(step)) 'pa-walking'].join(' '), [
    div(classes: 'par-rows', styles: Styles(raw: {'--n': '$height'}), [
      for (final (i, r) in rows.indexed)
        () {
          final shown = _at(r.text, step);
          // A hidden row keeps the text it had (or will have), so it fades
          // rather than blinks.
          var text = shown ?? r.text.lastWhere((t) => t != null, orElse: () => '')!;
          final isNew = text.startsWith('!');
          if (isNew) text = text.substring(1);
          return div(
            classes: [
              'par-row',
              if (isNew) 'is-new',
              if (shown == null) 'is-hidden',
              if (r.skip) 'is-skipped',
              if (r.walk != null) 'is-walked',
            ].join(' '),
            styles: Styles(
              raw: {
                '--i': '$i',
                '--pos': '${_at(r.pos, step)}',
                '--indent': '${_at(r.indent, step)}',
                if (r.walk != null) '--w': '${r.walk}',
              },
            ),
            // One inline run per line, so the spaces between tokens survive.
            [span(classes: 'par-code', _line(text))],
          );
        }(),
    ]),
  ]);
}

// Rename: the names to rename light up, then every use of each changes at
// once; the dependency's names are kept.

final _Story _rename = (
  label:
      'The names declared in your package light up, then every use of each changes to a short '
      'name at once, while the names from a dependency stay.',
  steps: 4,
  still: 2,
  stage: (step) => _rows(step, [
    _row(['class Payments {', 'class {x:Payments} {', 'class {x:a} {'], [0]),
    _row(
      ['final Gateway gateway;', 'final Gateway {x:gateway};', 'final Gateway {x:b};', 'final {k:Gateway} {x:b};'],
      [1],
      indent: [1],
    ),
    _row(
      [
        'String charge(String token) =>',
        'String {x:charge}(String {x:token}) =>',
        'String {x:c}(String {x:d}) =>',
      ],
      [2],
      indent: [1],
    ),
    _row(
      [
        'gateway.pay(token).id;',
        '{x:gateway}.pay({x:token}).id;',
        '{x:b}.pay({x:d}).id;',
        '{x:b}.{k:pay}({x:d}).{k:id};',
      ],
      [3],
      indent: [3],
    ),
    _row(['}'], [4]),
  ]),
);

// Arithmetic mangling: the same sum, through an equivalent expression.

final _Story _arith = (
  label: 'a + b with a = 6 and b = 3 gives 9; the mangled expression gives the same 9.',
  steps: 4,
  still: 3,
  stage: (step) => _rows(step, [
    _row(['{m:a = 6, b = 3}'], [0]),
    _row(['a + b', '{x:(a ^ b) + ((a & b) << 1)}'], [1]),
    _row(['= 9', null, '= {x:5} + {x:(2 << 1)}', '= 5 + 4 = 9'], [2]),
  ]),
);

// Opaque predicates: a condition joins the `if`, and it is true for any n.

final _Story _opaque = (
  label:
      'An always-true condition is joined to an if statement; for n = 7, -3 and 100000 it is '
      'true every time, so the branch still depends only on o.isPaid.',
  steps: 5,
  still: 2,
  stage: (step) => _rows(step, [
    _row(['void refund(Order o, int n) {'], [0]),
    _row(['if (o.isPaid) {', 'if (o.isPaid &&'], [1], indent: [1]),
    _row([null, '{x:(n & 0xFFFF) * (n & 0xFFFF) >= 0}) {'], [1, 2], indent: [3]),
    _row(['issueRefund(o, n);'], [2, 3], indent: [2]),
    _row(['}'], [3, 4], indent: [1]),
    _row(['}'], [4, 5]),
    _row(
      [
        null,
        null,
        '{m:n = 7}       → 49 ≥ 0         {x:true}',
        '{m:n = -3}      → 4294574089 ≥ 0 {x:true}',
        '{m:n = 100000}  → 1187767296 ≥ 0 {x:true}',
      ],
      [6],
    ),
  ]),
);

// Dead code: a guarded block appears, and execution walks past it.

final _Story _dead = (
  label:
      'A block guarded by a condition that is never true is inserted at the top of the body; '
      'execution walks past it to the real statements.',
  steps: 3,
  still: 2,
  stage: (step) => _rows(
    step,
    [
      _row(['int scale(int p) {'], [0]),
      _row([null, '!if ((p & 0xFFFF) * (p & 0xFFFF) < 0) {'], [1], indent: [1], walk: 0),
      _row([null, '!p + 40503;'], [1, 2], indent: [2], skip: true),
      _row([null, '!p * 12789;'], [1, 3], indent: [2], skip: true),
      _row([null, '!}'], [1, 4], indent: [1]),
      _row(['final factor = p * 2;'], [1, 5], indent: [1], walk: 1),
      _row(['return factor + 1;'], [2, 6], indent: [1], walk: 2),
      _row(['}'], [3, 7]),
    ],
    walkSteps: {2},
  ),
);

// Bogus control flow: the body is wrapped and cloned; execution always takes
// the real branch.

final _Story _bogus = (
  label:
      'The body is wrapped in a condition that is always true, with a copy of the body in the '
      'else branch; execution always takes the first branch.',
  steps: 3,
  still: 2,
  stage: (step) => _rows(
    step,
    [
      _row(['int fee(int n) {'], [0]),
      _row([null, '!if ((n & 0xFFFF) * (n & 0xFFFF) >= 0) {'], [1], indent: [1], walk: 0),
      _row(['final base = n ~/ 40;'], [1, 2], indent: [1, 2], walk: 1),
      _row(['return base + 25;'], [2, 3], indent: [1, 2], walk: 2),
      _row([null, '!} else {'], [2, 4], indent: [1]),
      // The copy starts on top of the original and slides down into the else.
      _row([null, '!final base = n ~/ 40;'], [1, 5], indent: [1, 2], skip: true),
      _row([null, '!return base + 25;'], [2, 6], indent: [1, 2], skip: true),
      _row([null, '!}'], [2, 7], indent: [1]),
      _row(['}'], [3, 8]),
    ],
    walkSteps: {2},
  ),
);

// Call indirection: direct calls get rerouted through the forwarder, and the
// call graph loses its edges to the real targets.

final _Story _call = (
  label:
      'total calls sum and withTax directly; then both calls go through refractorCall, and the '
      'call graph no longer shows which function total calls.',
  steps: 3,
  still: 2,
  stage: (step) => RawText('''
<svg class="pac" viewBox="0 0 320 150">
  <defs>
    <marker id="pac-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0 0L8 4L0 8Z"/>
    </marker>
  </defs>
  <line class="pac-edge pac-direct" x1="92" y1="75" x2="230" y2="36" marker-end="url(#pac-arrow)"/>
  <line class="pac-edge pac-direct" x1="92" y1="75" x2="230" y2="114" marker-end="url(#pac-arrow)"/>
  <line class="pac-edge pac-in" x1="92" y1="75" x2="114" y2="75" marker-end="url(#pac-arrow)"/>
  <line class="pac-edge pac-out" x1="212" y1="75" x2="230" y2="40" marker-end="url(#pac-arrow)"/>
  <line class="pac-edge pac-out" x1="212" y1="75" x2="230" y2="110" marker-end="url(#pac-arrow)"/>
  <g class="pac-node"><rect x="12" y="60" width="80" height="30" rx="4"/><text x="52" y="75">total()</text></g>
  <g class="pac-node pac-fwd"><rect x="116" y="60" width="96" height="30" rx="4"/><text x="164" y="75">refractorCall</text></g>
  <g class="pac-node"><rect x="232" y="20" width="80" height="30" rx="4"/><text x="272" y="35">sum()</text></g>
  <g class="pac-node"><rect x="232" y="100" width="80" height="30" rx="4"/><text x="272" y="115">withTax()</text></g>
</svg>'''),
);

// Control-flow flattening: four statements, numbered, shuffled, still run in
// order. Case numbers stay in source order and only the written order is
// shuffled, as in the transformer.

const _statements = [
  ('final total = cart.sum();', 'total = cart.sum();'),
  ('log(total);', 'log(total);'),
  ('charge(total);', 'charge(total);'),
  ('return total;', 'return total;'),
];

/// The order the cases are written in: slot s holds case `_layout[s]`.
const _layout = [2, 0, 3, 1];

final _Story _flatten = (
  label:
      'Four statements become numbered cases of a switch, the cases are shuffled, '
      'and execution still visits them in their original order.',
  steps: 4,
  still: 3,
  stage: (step) => div(classes: 'paf', [
    code(classes: 'paf-hoist', [Component.text('int total;')]),
    code(classes: 'paf-switch', [Component.text('switch (0) {')]),
    div(classes: 'paf-rows', [
      for (final (i, (before, after)) in _statements.indexed)
        div(
          classes: 'paf-row',
          styles: Styles(raw: {'--i': '$i', '--pos': '${step >= 2 ? _layout.indexOf(i) : i}'}),
          [
            span(classes: 'paf-case', [Component.text('case $i:')]),
            code(classes: 'paf-code', [Component.text(step == 0 ? before : after)]),
            span(classes: 'paf-next', [
              Component.text(i + 1 < _statements.length ? '→ case ${i + 1}' : 'exits'),
            ]),
          ],
        ),
    ]),
  ]),
);

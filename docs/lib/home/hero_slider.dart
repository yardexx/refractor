import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The landing page's hero picture: one small class, as source and as the
/// obfuscated build, stacked exactly on top of each other. A divider with the
/// logo's prism on its handle splits them; drag it (or use the arrow keys)
/// and the code turns into the build as the prism passes over it.
///
/// The build layer is clipped with `clip-path: inset(0 0 0 var(--split))`, so
/// left of the prism you read the source and right of it the build. A native
/// range input lies over the card for pointer and keyboard; a few lines of
/// inline script copy its value into `--split`. On load the prism sweeps in
/// once from the right (home.css). The output is hand-modelled, like the
/// playground's.
class HeroSlider extends StatelessComponent {
  const HeroSlider({super.key});

  // `{kind:text}` is a token, `{kind.pass:text}` a token a pass produced;
  // anything else is punctuation.
  static const _source = [
    '{kw:class} {ty:OrderClient} {',
    "  {kw:final} {id:endpoint} = {str:'https://api.acme.dev/orders'};",
    '',
    '  {ty:String} {fn:route}({ty:int} {id:items}, {ty:int} {id:extra}) {',
    '    {kw:final} {id:total} = {id:items} + {id:extra};',
    "    {kw:final} {id:error} = {str:'Order is too large to place'};",
    '    {kw:return} {id:total} < {num:250} ? {id:endpoint} : {id:error};',
    '  }',
    '}',
  ];

  static const _build = [
    '{kw:class} {ty.rename:a} {',
    '  {kw:final} {id.rename:b} = {fn.strings:i}{p.strings:([}{num.strings:0x6f, 0x1c, 0xe2, …}'
        '{p.strings:], }{num.strings:0x7d21}{p.strings:)};',
    '',
    '  {ty:String} {fn.rename:c}({ty:int} {id.rename:d}, {ty:int} {id.rename:e}) {',
    '    {kw:final} {id.rename:f} = {p.arith:(}{id.rename:d}{p.arith: ^ }{id.rename:e}{p.arith:) + ((}'
        '{id.rename:d}{p.arith: & }{id.rename:e}{p.arith:) << }{num.arith:1}{p.arith:)};',
    '    {kw:final} {id.rename:g} = {fn.strings:i}{p.strings:([}{num.strings:0x13, 0xa8, 0x4b, …}'
        '{p.strings:], }{num.strings:0x0c9f}{p.strings:)};',
    '    {kw:return} {id.rename:f} < {fn.ints:j}{p.ints:(}{num.ints:0x51e3}{p.ints:, }{num.ints:0x5119}'
        '{p.ints:)} ? {id.rename:b} : {id.rename:g};',
    '  }',
    '}',
  ];

  static final _token = RegExp(r'\{(\w+)(?:\.(\w+))?:([^}]*)\}');

  static Component _line(String markup) {
    final parts = <Component>[];
    var at = 0;
    for (final m in _token.allMatches(markup)) {
      if (m.start > at) parts.add(span(classes: 'tk-p', [Component.text(markup.substring(at, m.start))]));
      final pass = m[2];
      parts.add(
        span(classes: ['tk-${m[1]}', if (pass != null) 'fx fx-$pass'].join(' '), [Component.text(m[3]!)]),
      );
      at = m.end;
    }
    if (at < markup.length) parts.add(span(classes: 'tk-p', [Component.text(markup.substring(at))]));
    return span(classes: 'pg-line', parts);
  }

  static Component _layer(List<String> lines, String classes) =>
      pre(classes: 'hsl-code $classes', attributes: {'aria-hidden': 'true'}, [for (final l in lines) _line(l)]);

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'pg hero-slider',
      attributes: {'data-ui': ''},
      [
        div(classes: 'pg-pane-head hsl-head', [
          code(classes: 'pg-path', [Component.text('lib/order_client.dart')]),
          span(classes: 'pg-tag', [
            code(classes: 'pg-path', [Component.text('build/out')]),
            span(classes: 'hsl-tag-note', [Component.text(', shown as Dart')]),
          ]),
        ]),
        div(classes: 'hsl-stage', [
          _layer(_source, 'hsl-source'),
          _layer(_build, 'hsl-build pg-out'),
          div(
            classes: 'hsl-handle',
            attributes: {'aria-hidden': 'true'},
            [span(classes: 'prism-mark', [])],
          ),
          input(
            type: InputType.range,
            classes: 'hsl-range',
            attributes: {
              'min': '0',
              'max': '100',
              'value': '40',
              'aria-label': 'Drag the prism to obfuscate the code',
            },
          ),
        ]),
        RawText('''
<script>
document.querySelectorAll('.hero-slider').forEach((card) => {
  const range = card.querySelector('.hsl-range');
  range.addEventListener('input', () => {
    card.dataset.touched = '';
    card.style.setProperty('--split', range.value + '%');
  });
});
</script>'''),
      ],
    );
  }
}

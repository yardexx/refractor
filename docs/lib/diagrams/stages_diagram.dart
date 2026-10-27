import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'autoplay.dart';
import 'frame.dart';

/// A pass's five stages. The type flowing between them (Component → S → P →
/// O → PassResult) rides along the connectors; only transform touches the AST.
@client
class StagesDiagram extends StatefulComponent {
  const StagesDiagram({super.key});

  @override
  State<StagesDiagram> createState() => _StagesDiagramState();
}

typedef _Stage = ({String name, String input, String signature, String text, String effect, String tone});

const List<_Stage> _stages = [
  (
    name: 'select',
    input: 'Component',
    signature: 'S select(Component)',
    text: 'Walk the AST and gather the eligible nodes into an immutable selection.',
    effect: 'Reads only',
    tone: 'read',
  ),
  (
    name: 'plan',
    input: 'S',
    signature: 'Future<P> plan(Component, S)',
    text:
        'Turn the selection into exact decisions. The smart domain reasoning lives here, and the plan can be '
        'checked and serialized before anything changes.',
    effect: 'Reads only',
    tone: 'read',
  ),
  (
    name: 'transform',
    input: 'P',
    signature: 'Future<O> apply(Component, P)',
    text: 'Apply the plan. The only stage that mutates the AST; it returns counts and an artifact.',
    effect: 'Mutates the AST',
    tone: 'write',
  ),
  (
    name: 'validate',
    input: 'O',
    signature: 'validate(Component, {plan, output})',
    text: 'Assert post-conditions and throw on any violation. Rename uses it; most passes keep the no-op default.',
    effect: 'Asserts',
    tone: 'check',
  ),
  (
    name: 'report',
    input: '✓',
    signature: 'PassReport + PassArtifact',
    text:
        'Package metrics for people and CI, and the durable machine-readable artifact. The pass returns '
        'PassSucceeded, or PassFailed if any stage threw.',
    effect: 'Returns PassResult',
    tone: 'out',
  ),
];

class _StagesDiagramState extends State<StagesDiagram> with Autoplay<StagesDiagram> {
  @override
  int get stepCount => _stages.length;

  @override
  Component build(BuildContext context) {
    final current = _stages[step];
    return diagramFrame(
      title: 'Inside run()',
      classes: 'dg-stages',
      playing: playing,
      onTogglePlay: togglePlay,
      children: [
        div(classes: 'dg-track', [
          for (final (i, s) in _stages.indexed)
            button(
              classes: ['dg-node', 'dg-${s.tone}', if (i < step) 'done', if (i == step) 'active'].join(' '),
              attributes: {'aria-pressed': '${i == step}'},
              onClick: () => goTo(i),
              [
                span(classes: 'dg-type', [Component.text(s.input)]),
                span(classes: 'dg-dot', [Component.text('${i + 1}')]),
                span(classes: 'dg-label', [Component.text(s.name)]),
              ],
            ),
        ]),
        detailPanel(
          id: 'stage-$step',
          children: [
            div(classes: 'dg-detail-head', [
              span(classes: 'dg-detail-title', [Component.text(current.name)]),
              span(classes: 'dg-effect dg-${current.tone}', [Component.text(current.effect)]),
            ]),
            code(classes: 'dg-call', [Component.text(current.signature)]),
            p([Component.text(current.text)]),
          ],
        ),
      ],
    );
  }
}

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'autoplay.dart';
import 'frame.dart';

/// `RefractorEngine.run` as a track of seven steps, from source to binary.
/// A pulse tours the steps; clicking one shows what happens there.
@client
class PipelineDiagram extends StatefulComponent {
  const PipelineDiagram({super.key});

  @override
  State<PipelineDiagram> createState() => _PipelineDiagramState();
}

typedef _Step = ({String title, String short, String call, String text, String kind});

const List<_Step> _steps = [
  (
    title: 'Compile to kernel',
    short: 'compile',
    call: 'compiler.compileToKernel(input) → app.dill',
    text:
        'dart compile kernel turns your entrypoint into a .dill. The front end has already resolved every type, '
        'call target and override, which is what makes safe renaming possible.',
    kind: 'io',
  ),
  (
    title: 'Load',
    short: 'load',
    call: 'kernelIO.load(app.dill) → Component',
    text: 'The .dill is read into a Component: the kernel AST every pass works on.',
    kind: 'io',
  ),
  (
    title: 'Plan the run',
    short: 'plan',
    call: 'PassRegistry.createAll(…) → List<Pass>',
    text:
        'ProjectScope decides what counts as your code, and each enabled pass is built with its config and its '
        'own keep policy.',
    kind: 'core',
  ),
  (
    title: 'Run the passes',
    short: 'passes',
    call: 'PassRunner.run(component)',
    text:
        'The passes run in order and rewrite the AST in place. Every result is collected, failures included, '
        'so one report shows them all.',
    kind: 'passes',
  ),
  (
    title: 'Gate',
    short: 'gate',
    call: 'if (failures.isNotEmpty) stop',
    text:
        'If any pass failed, the build stops here and writes nothing. Refractor never ships a half-obfuscated '
        'binary.',
    kind: 'gate',
  ),
  (
    title: 'Write',
    short: 'write',
    call: 'kernelIO.write(…) → app.obfuscated.dill',
    text: 'The rewritten AST is serialized back to kernel.',
    kind: 'io',
  ),
  (
    title: 'Compile the target',
    short: 'binary',
    call: 'compiler.compileToTarget(…) → exe · aot · jit',
    text:
        'dart compile turns the obfuscated kernel into a native executable or an AOT or JIT snapshot. For the '
        'kernel target, the .dill itself is the output.',
    kind: 'io',
  ),
];

class _PipelineDiagramState extends State<PipelineDiagram> with Autoplay<PipelineDiagram> {
  @override
  int get stepCount => _steps.length;

  @override
  Component build(BuildContext context) {
    final current = _steps[step];
    return diagramFrame(
      title: 'The compile pipeline',
      classes: 'dg-pipeline',
      playing: playing,
      onTogglePlay: togglePlay,
      children: [
        div(classes: 'dg-track', [
          for (final (i, s) in _steps.indexed)
            button(
              classes: [
                'dg-node',
                'dg-${s.kind}',
                if (i < step) 'done',
                if (i == step) 'active',
              ].join(' '),
              attributes: {'aria-pressed': '${i == step}'},
              onClick: () => goTo(i),
              [
                span(classes: 'dg-dot', [Component.text(s.kind == 'gate' ? '?' : '${i + 1}')]),
                span(classes: 'dg-label', [Component.text(s.short)]),
              ],
            ),
        ]),
        detailPanel(
          id: 'step-$step',
          children: [
            div(classes: 'dg-detail-head', [
              span(classes: 'dg-step', [Component.text('Step ${step + 1} of ${_steps.length}')]),
              span(classes: 'dg-detail-title', [Component.text(current.title)]),
            ]),
            code(classes: 'dg-call', [Component.text(current.call)]),
            p([Component.text(current.text)]),
            if (current.kind == 'gate')
              div(classes: 'dg-branches', [
                span(classes: 'dg-branch dg-branch-ok', [Component.text('✓ all passes succeeded → write')]),
                span(classes: 'dg-branch dg-branch-stop', [Component.text('✗ any pass failed → stop, no output')]),
              ]),
          ],
        ),
      ],
    );
  }
}

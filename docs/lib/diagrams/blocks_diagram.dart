import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'autoplay.dart';
import 'frame.dart';

/// Refractor's blocks as nested boxes: the CLI on top, the dart:io line it
/// alone may cross, and the engine with its parts. The CLI's IO
/// implementations visibly flow down into the engine's abstract boundary.
@client
class BlocksDiagram extends StatefulComponent {
  const BlocksDiagram({super.key});

  @override
  State<BlocksDiagram> createState() => _BlocksDiagramState();
}

typedef _Block = ({String id, String name, String sub, String text});

const List<_Block> _blocks = [
  (
    id: 'cli',
    name: 'CLI + Config',
    sub: 'dart:io',
    text:
        'The user-facing commands, and turning refractor.yaml into typed config. The only layer allowed to touch '
        'dart:io; it builds the IO implementations and hands them to the engine.',
  ),
  (
    id: 'orchestrator',
    name: 'Orchestrator',
    sub: 'RefractorEngine · PassRegistry · PassRunner',
    text: 'Creates, orders and runs the passes, collects their results, and refuses to emit output if any failed.',
  ),
  (
    id: 'passes',
    name: 'Passes',
    sub: 'nine passes',
    text:
        'One unit of obfuscation each, built as the same five-stage pipeline: select, plan, transform, validate, report.',
  ),
  (
    id: 'policy',
    name: 'Policy',
    sub: 'ObfuscationScope',
    text:
        'Answers one question for every pass: may I change this declaration? Yes, if it is in your project and not kept.',
  ),
  (
    id: 'toolkit',
    name: 'kernel_toolkit',
    sub: 'shared kernel operations',
    text: 'Shared helpers the passes use instead of handling raw package:kernel everywhere.',
  ),
  (
    id: 'boundary',
    name: 'Compile / serialize boundary',
    sub: 'Compiler · KernelIO (abstract)',
    text:
        'Two interfaces, Compiler and KernelIO. The engine depends only on them, which keeps it unit-testable '
        'without processes or disk; the CLI injects DartCompiler and FileKernelIO.',
  ),
];

class _BlocksDiagramState extends State<BlocksDiagram> with Autoplay<BlocksDiagram> {
  @override
  int get stepCount => _blocks.length;

  Component _block(String id, {String extra = ''}) {
    final i = _blocks.indexWhere((b) => b.id == id);
    final b = _blocks[i];
    return button(
      classes: 'dg-block dg-block-$id${i == step ? ' active' : ''}$extra',
      attributes: {'aria-pressed': '${i == step}'},
      onClick: () => goTo(i),
      [
        span(classes: 'dg-block-name', [Component.text(b.name)]),
        span(classes: 'dg-block-sub', [Component.text(b.sub)]),
      ],
    );
  }

  @override
  Component build(BuildContext context) {
    final current = _blocks[step];
    return diagramFrame(
      title: 'The blocks',
      classes: 'dg-blocks focus-${current.id}',
      playing: playing,
      onTogglePlay: togglePlay,
      children: [
        _block('cli'),
        div(classes: 'dg-io-line', [
          span(classes: 'dg-io-label', [Component.text('dart:io stops here')]),
          span(classes: 'dg-inject', [Component.text('DartCompiler · FileKernelIO  ↓ injected')]),
        ]),
        div(classes: 'dg-engine', [
          span(classes: 'dg-engine-label', [Component.text('Engine · zero dart:io')]),
          _block('orchestrator'),
          div(classes: 'dg-row', [_block('passes'), _block('policy'), _block('toolkit')]),
          _block('boundary'),
        ]),
        detailPanel(
          id: 'block-${current.id}',
          children: [
            div(classes: 'dg-detail-head', [
              span(classes: 'dg-detail-title', [Component.text(current.name)]),
            ]),
            p([Component.text(current.text)]),
          ],
        ),
      ],
    );
  }
}

/// Markdown tags for the Architecture diagrams. Each renders its diagram plus
/// the shared stylesheet (`web/styles/diagrams.css`).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'blocks_diagram.dart';
import 'pipeline_diagram.dart';
import 'policy_explorer.dart';
import 'stages_diagram.dart';

/// `<PipelineDiagram />`, `<BlocksDiagram />`, `<StagesDiagram />`,
/// `<PolicyExplorer />` and the static `<DependencyRule />`.
class Diagrams extends CustomComponentBase {
  const Diagrams();

  static const _diagrams = {
    'PipelineDiagram': PipelineDiagram(),
    'BlocksDiagram': BlocksDiagram(),
    'StagesDiagram': StagesDiagram(),
    'PolicyExplorer': PolicyExplorer(),
    'DependencyRule': _DependencyRule(),
  };

  @override
  Pattern get pattern => RegExp('^(${_diagrams.keys.join('|')})\$');

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    return Component.fragment([
      Document.head(
        children: [link(id: 'diagrams-css', rel: 'stylesheet', href: '/styles/diagrams.css')],
      ),
      _diagrams[name]!,
    ]);
  }
}

/// The one-way dependency rule: CLI → Config → Engine, with the dart:io line.
class _DependencyRule extends StatelessComponent {
  const _DependencyRule();

  @override
  Component build(BuildContext context) {
    Component node(String name, String note, {String extra = ''}) => div(classes: 'dr-node$extra', [
      span(classes: 'dr-name', [Component.text(name)]),
      span(classes: 'dr-note', [Component.text(note)]),
    ]);

    // The flow sits in its own element so the card's container query can
    // turn it vertical on narrow screens.
    return div(classes: 'dg dg-rule', [
      div(classes: 'dr-flow', [
        node('CLI', 'dart:io'),
        span(classes: 'dr-arrow', []),
        node('Config', 'typed'),
        span(classes: 'dr-arrow dr-io', [
          span(classes: 'dr-io-label', [Component.text('No dart:io past here')]),
        ]),
        node('Engine', 'zero dart:io', extra: ' dr-engine'),
      ]),
    ]);
  }
}

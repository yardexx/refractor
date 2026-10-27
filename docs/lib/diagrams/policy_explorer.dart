import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'frame.dart';

/// The policy formula, worked through: pick a declaration and a pass and see
/// membership and keep decide whether it gets obfuscated.
@client
class PolicyExplorer extends StatefulComponent {
  const PolicyExplorer({super.key});

  @override
  State<PolicyExplorer> createState() => _PolicyExplorerState();
}

typedef _Case = ({
  String label,
  String where,
  bool inProject,
  String membership,
  bool Function(bool rename) kept,
  String Function(bool rename) keep,
});

final List<_Case> _cases = [
  (
    label: 'Payments.charge',
    where: 'package:app/src/payments.dart',
    inProject: true,
    membership: 'A package: URI matching your pubspec name, under lib/.',
    kept: (_) => false,
    keep: (_) => 'No exclude glob, annotation or entry point covers it.',
  ),
  (
    label: 'Client.get',
    where: 'package:http/http.dart',
    inProject: false,
    membership: 'A dependency, not your package. External code is never touched.',
    kept: (_) => false,
    keep: (_) => 'Not asked: keep only applies to project code.',
  ),
  (
    label: 'Order.toJson',
    where: 'lib/src/order.g.dart',
    inProject: true,
    membership: 'A file in your package.',
    kept: (_) => true,
    keep: (_) => 'Matches the global exclude glob **/*.g.dart, so the whole library is kept.',
  ),
  (
    label: 'class PublicApi',
    where: '@Refractor.keep() in lib/api.dart',
    inProject: true,
    membership: 'A file in your package.',
    kept: (_) => true,
    keep: (_) => 'Annotated with @Refractor.keep(), so the class and its members are kept.',
  ),
  (
    label: 'main',
    where: 'bin/app.dart',
    inProject: true,
    membership: 'A file: URI under the project root.',
    kept: (rename) => rename,
    keep: (rename) => rename
        ? 'The entry point. Rename honors it, so main keeps its name.'
        : "The entry point, but this pass doesn't honor it: keeping main's name says nothing about the strings inside.",
  ),
];

class _PolicyExplorerState extends State<PolicyExplorer> {
  int _case = 0;
  bool _rename = true;

  @override
  Component build(BuildContext context) {
    final c = _cases[_case];
    final kept = c.inProject && c.kept(_rename);
    final obfuscated = c.inProject && !kept;

    Component term(String name, String owner, bool? ok, String why) => div(
      classes:
          'dg-term ${ok == null
              ? 'skip'
              : ok
              ? 'yes'
              : 'no'}',
      [
        span(classes: 'dg-term-name', [Component.text(name)]),
        span(classes: 'dg-term-owner', [Component.text(owner)]),
        span(classes: 'dg-term-mark', [
          Component.text(
            ok == null
                ? '–'
                : ok
                ? '✓'
                : '✗',
          ),
        ]),
        span(classes: 'dg-term-why', [Component.text(why)]),
      ],
    );

    return diagramFrame(
      title: 'Try the policy',
      classes: 'dg-policy',
      children: [
        div(classes: 'dg-controls', [
          div(classes: 'dg-choices', [
            for (final (i, k) in _cases.indexed)
              button(
                classes: 'dg-choice${i == _case ? ' active' : ''}',
                attributes: {'aria-pressed': '${i == _case}'},
                onClick: () => setState(() => _case = i),
                [
                  code([Component.text(k.label)]),
                ],
              ),
          ]),
          div(classes: 'dg-seg', [
            for (final rename in [true, false])
              button(
                classes: 'dg-seg-btn${rename == _rename ? ' active' : ''}',
                attributes: {'aria-pressed': '${rename == _rename}'},
                onClick: () => setState(() => _rename = rename),
                [Component.text(rename ? 'rename' : 'string_encrypt')],
              ),
          ]),
        ]),
        div(classes: 'dg-where', [
          code([Component.text(c.where)]),
        ]),
        div(key: ValueKey('$_case-$_rename'), classes: 'dg-formula', [
          term('in the project', 'ProjectScope', c.inProject, c.membership),
          span(classes: 'dg-op', [Component.text('and')]),
          term('not kept', 'KeepPolicy', c.inProject ? !kept : null, c.keep(_rename)),
          span(classes: 'dg-op', [Component.text('=')]),
          div(classes: 'dg-verdict ${obfuscated ? 'yes' : 'no'}', [
            Component.text(obfuscated ? 'Obfuscated' : 'Left alone'),
          ]),
        ]),
      ],
    );
  }
}

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'copy_code_button.dart';
import 'highlight.dart';

/// Renders every fenced code block as a code panel: the site's dark editor
/// card with a header (window dots, language, copy button) and the shared
/// syntax colors. Replaces jaspr_content's `CodeBlock`.
///
/// The fence's language picks the highlighter: `dart`, `yaml`, `sh`, `json`,
/// or `text`. Shell lines get a `$` prompt that isn't part of the copied text.
class CodePanel extends CustomComponent {
  const CodePanel() : super.base();

  static const _labels = {'dart': 'Dart', 'yaml': 'YAML', 'sh': 'Shell', 'json': 'JSON', 'text': 'Text'};

  @override
  Component? create(Node node, NodesBuilder builder) {
    if (node case ElementNode(tag: 'pre', children: [ElementNode(tag: 'code', :final attributes, :final children)])) {
      final cls = attributes['class'] ?? '';
      final language = cls.startsWith('language-') ? cls.substring('language-'.length) : 'text';
      final source = (children ?? []).map((c) => c.innerText).join().replaceFirst(RegExp(r'\n$'), '');
      return _CodePanel(language: language, label: _labels[language] ?? language, source: source);
    }
    return null;
  }
}

class _CodePanel extends StatelessComponent {
  const _CodePanel({required this.language, required this.label, required this.source});

  final String language;
  final String label;
  final String source;

  @override
  Component build(BuildContext context) {
    final lines = <List<CodeToken>>[[]];
    for (final t in highlight(source, language)) {
      if (t.kind == 'nl') {
        lines.add([]);
      } else {
        lines.last.add(t);
      }
    }
    final shell = language == 'sh';

    return Component.fragment([
      Document.head(
        children: [link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css')],
      ),
      div(classes: 'cb cb-$language', [
        div(classes: 'cb-head', [
          span(classes: 'pg-lights', [span([]), span([]), span([])]),
          span(classes: 'cb-lang', [Component.text(label)]),
          CopyCodeButton(text: source),
        ]),
        pre(classes: 'cb-code', [
          code([
            for (final line in lines)
              span(
                classes: [
                  'cb-line',
                  if (shell && line.any((t) => t.significant) && line.firstWhere((t) => t.significant).kind != 'cm')
                    'cb-cmd',
                ].join(' '),
                [
                  for (final t in line) span(classes: 'tk-${t.kind}', [Component.text(t.text)]),
                ],
              ),
          ]),
        ]),
      ]),
    ]);
  }
}

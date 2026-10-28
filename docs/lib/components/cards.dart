/// Cards for any docs page: a title with a colored dot, a short markdown body,
/// and an optional link. Styles live in `web/styles/cards.css`.
///
/// ````md
/// <Cards>
/// <Card title="Rename" href="/rulebook/rename" color="naming">
///
/// Rewrites identifiers to short, meaningless names.
///
/// </Card>
/// </Cards>
/// ````
///
/// `color` is a Rulebook category (`naming`, `expressions`, `control`, as in
/// code-card.css) or any CSS color; it tints the dot, the top edge and the
/// hover border. Leave a blank line around the body so its markdown is parsed.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../rulebook/passes.dart';

/// `<Cards>`: lays its cards out in a responsive grid.
class Cards extends CustomComponentBase {
  const Cards();

  @override
  Pattern get pattern => RegExp(r'^Cards$');

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) => cardGrid([?child]);
}

/// `<Card title="…" href="…" color="…">`, its body as markdown.
class Card extends CustomComponentBase {
  const Card();

  @override
  Pattern get pattern => RegExp(r'^Card$');

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    final title = attributes['title'];
    if (title == null) throw ArgumentError('<Card> needs a title="…" attribute.');
    return card(title: title, href: attributes['href'], color: attributes['color'], body: child);
  }
}

/// The stylesheets a card needs; head elements with the same id are merged.
Component _styles() => Document.head(
  children: [
    link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css'),
    link(id: 'cards-css', rel: 'stylesheet', href: '/styles/cards.css'),
  ],
);

/// A grid of [cards].
Component cardGrid(List<Component> cards) => Component.fragment([
  _styles(),
  div(classes: 'cards', cards),
]);

/// One card. With [href] the whole card is a link.
Component card({required String title, String? href, String? color, Component? body}) {
  final isGroup = color != null && PassGroup.values.any((group) => group.slug == color);
  final classes = ['card', if (isGroup) 'pc-$color'].join(' ');
  final styles = color != null && !isGroup ? Styles(raw: {'--pc': color}) : null;
  final content = [
    span(classes: 'card-title', [
      span(classes: 'card-dot', []),
      Component.text(title),
    ]),
    if (body != null) div(classes: 'card-body', [body]),
  ];

  return Component.fragment([
    _styles(),
    if (href != null)
      a(classes: classes, href: href, styles: styles, content)
    else
      div(classes: classes, styles: styles, content),
  ]);
}

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The site header with the Refractor wordmark.
///
/// Mirrors jaspr_content's `Header` (same classes, so `DocsLayout` positions it
/// the same way), but its title is the wordmark rather than an icon and a text
/// label. The wordmark has a light and a dark variant; CSS shows the one that
/// matches the theme toggle's `data-theme`.
class BrandHeader extends StatelessComponent {
  const BrandHeader({this.leading = const [], this.items = const [], super.key});

  /// Components before the wordmark, such as the sidebar toggle.
  final List<Component> leading;

  /// Components on the right, such as the theme toggle and GitHub button.
  final List<Component> items;

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.head(
        children: [
          link(rel: 'apple-touch-icon', href: '/apple-touch-icon.png'),
          Style(styles: _styles),
        ],
      ),
      header(classes: 'header', [
        ...leading,
        a(classes: 'header-title', href: '/', [
          img(classes: 'brand-on-light', src: '/images/refractor-wordmark-light.svg', alt: 'Refractor'),
          img(classes: 'brand-on-dark', src: '/images/refractor-wordmark-dark.svg', alt: 'Refractor'),
        ]),
        div(classes: 'header-content', [
          div(classes: 'header-items', items),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get _styles => [
    css('.header', [
      css('&').styles(
        display: Display.flex,
        height: 4.rem,
        padding: Padding.symmetric(horizontal: 1.rem, vertical: .25.rem),
        margin: Margin.symmetric(horizontal: Unit.auto),
        border: Border.only(
          bottom: BorderSide(color: Color('#0000000d'), width: 1.px),
        ),
        alignItems: AlignItems.center,
        gap: Gap.column(1.rem),
      ),
      css.media(MediaQuery.all(minWidth: 768.px), [css('&').styles(padding: Padding.symmetric(horizontal: 2.5.rem))]),
      css('.header-title', [
        css('&').styles(
          display: Display.inlineFlex,
          alignItems: AlignItems.center,
          flex: Flex(basis: 17.rem),
        ),
        css('img').styles(width: Unit.auto, height: 1.75.rem),
      ]),
      css('.header-content', [
        css('&').styles(
          display: Display.flex,
          justifyContent: JustifyContent.end,
          flex: Flex(grow: 1),
        ),
      ]),
      css('.header-items', [
        css('&').styles(
          display: Display.flex,
          gap: Gap.column(0.25.rem),
        ),
      ]),
    ]),
    css('.brand-on-dark').styles(display: Display.none),
    css('[data-theme="dark"] .brand-on-light').styles(display: Display.none),
    css('[data-theme="dark"] .brand-on-dark').styles(display: Display.block),
  ];
}

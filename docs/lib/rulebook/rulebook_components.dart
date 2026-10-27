/// Markdown components for the Rulebook pages. Styles live in
/// `web/styles/rulebook.css`; pass colors come from `code-card.css`.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'copy_chip.dart';
import 'passes.dart';

/// The stylesheets every Rulebook component needs. Head elements with the same
/// id are merged, so each component can ask for them.
Component _styles() => Document.head(
  children: [
    link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css'),
    link(id: 'rulebook-css', rel: 'stylesheet', href: '/styles/rulebook.css'),
  ],
);

PassInfo _passOf(Map<String, String> attributes, String tag) {
  final slug = attributes['pass'];
  if (slug == null) throw ArgumentError('<$tag> needs a pass="…" attribute.');
  return passBySlug(slug);
}

/// `<PassFacts pass="strings">`: the strip under a pass page's title with its
/// group, config key, whether the starter config enables it, and the keep
/// rules it honors.
class PassFacts extends CustomComponentBase {
  const PassFacts();

  @override
  Pattern get pattern => 'PassFacts';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    final pass = _passOf(attributes, name);
    Component keep(String label, bool honored) => span(classes: 'pf-keep${honored ? '' : ' pf-off'}', [
      span(classes: 'pf-mark', [Component.text(honored ? '✓' : '–')]),
      Component.text(label),
    ]);

    return Component.fragment([
      _styles(),
      div(classes: 'pass-facts pc-${pass.slug}', [
        span(classes: 'pf-chip pf-group', [
          span(classes: 'pf-dot', []),
          Component.text(pass.group.label),
        ]),
        CopyChip(text: pass.configKey),
        span(classes: 'pf-chip${pass.inStarterConfig ? ' pf-on' : ''}', [
          Component.text(pass.inStarterConfig ? 'In the starter config' : 'Opt-in'),
        ]),
        span(classes: 'pf-chip pf-keeps', [
          span(classes: 'pf-label', [Component.text('Keeps')]),
          keep('excludes', true),
          keep('@Refractor.keep()', true),
          keep('entry point', pass.keepsEntryPoint),
        ]),
      ]),
    ]);
  }
}

/// `<PassPager pass="strings">`: links to the previous and next pass, in
/// Rulebook order, each tinted with its pass color.
class PassPager extends CustomComponentBase {
  const PassPager();

  @override
  Pattern get pattern => 'PassPager';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    final pass = _passOf(attributes, name);
    final i = rulebookPasses.indexOf(pass);
    final prev = i > 0 ? rulebookPasses[i - 1] : null;
    final next = i + 1 < rulebookPasses.length ? rulebookPasses[i + 1] : null;

    Component card(PassInfo p, String direction) => a(classes: 'pp-card pp-$direction pc-${p.slug}', href: p.page, [
      span(classes: 'pp-dir', [Component.text(direction == 'prev' ? '← Previous pass' : 'Next pass →')]),
      span(classes: 'pp-title', [
        span(classes: 'pf-dot', []),
        Component.text(p.title),
      ]),
    ]);

    return Component.fragment([
      _styles(),
      nav(
        classes: 'pass-pager',
        attributes: {'aria-label': 'Rulebook passes'},
        [
          if (prev != null) card(prev, 'prev') else span([]),
          if (next != null)
            card(next, 'next')
          else
            a(classes: 'pp-card pp-next', href: '/rulebook', [
              span(classes: 'pp-dir', [Component.text('All passes →')]),
              span(classes: 'pp-title', [Component.text('Rulebook overview')]),
            ]),
        ],
      ),
    ]);
  }
}

/// `<PassGrid>`: every pass as a card, grouped, with a one-line taste of what
/// it does to code.
class PassGrid extends CustomComponentBase {
  const PassGrid();

  @override
  Pattern get pattern => 'PassGrid';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    return Component.fragment([
      _styles(),
      div(classes: 'pass-grid', [
        for (final group in PassGroup.values) ...[
          h3(classes: 'rg-group', [Component.text(group.label)]),
          div(classes: 'rg-cards', [
            for (final p in rulebookPasses.where((p) => p.group == group))
              a(classes: 'rg-card pc-${p.slug}', href: p.page, [
                span(classes: 'rg-title', [
                  span(classes: 'pf-dot', []),
                  Component.text(p.title),
                ]),
                span(classes: 'rg-summary', [Component.text(p.summary)]),
                span(classes: 'rg-code', [
                  code(classes: 'rg-before', [Component.text(p.before)]),
                  span(classes: 'rg-arrow', [Component.text('→')]),
                  code(classes: 'rg-after', [Component.text(p.after)]),
                ]),
              ]),
          ]),
        ],
      ]),
    ]);
  }
}

/// `<Guarantees>` holding a `<Promises>` and a `<Caveats>` list: what a pass
/// promises next to what it doesn't, as two cards.
class Guarantees extends CustomComponentBase {
  const Guarantees();

  @override
  Pattern get pattern => 'Guarantees';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) {
    return Component.fragment([
      _styles(),
      div(classes: 'pass-cards', [?child]),
    ]);
  }
}

class Promises extends CustomComponentBase {
  const Promises();

  @override
  Pattern get pattern => 'Promises';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) =>
      _card('pass-card pass-card-ok', '✓', 'What it promises', child);
}

class Caveats extends CustomComponentBase {
  const Caveats();

  @override
  Pattern get pattern => 'Caveats';

  @override
  Component apply(String name, Map<String, String> attributes, Component? child) =>
      _card('pass-card pass-card-warn', '!', "What it doesn't do", child);
}

Component _card(String classes, String mark, String title, Component? child) {
  return div(classes: classes, [
    div(classes: 'pass-card-head', [
      span(classes: 'pass-card-mark', [Component.text(mark)]),
      Component.text(title),
    ]),
    div(classes: 'pass-card-body', [?child]),
  ]);
}

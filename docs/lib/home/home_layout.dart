import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../components/copy_code_button.dart';
import '../rulebook/passes.dart';
import 'hero_slider.dart';
import 'playground.dart';

const _install = 'dart pub global activate --source git https://github.com/yardexx/refractor.git';

/// The landing page: the prism hero, the pass [Playground], what you get, the
/// first commands, and the wordmark as a close.
///
/// The logo's prism runs the page: at full size in the hero, as a beam that
/// splits between the two halves of the page, and as the list marker. Color
/// means a pass, as on the docs pages. Selected with `layout: home`. Styles
/// live in `web/styles/home.css`, and the playground's code card in
/// `web/styles/code-card.css`.
class HomeLayout extends PageLayoutBase {
  const HomeLayout({required this.header});

  /// The site header, usually the same `BrandHeader` the docs use minus the
  /// sidebar toggle.
  final Component header;

  @override
  String get name => 'home';

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield link(id: 'code-card-css', rel: 'stylesheet', href: '/styles/code-card.css');
    yield link(rel: 'stylesheet', href: '/styles/home.css');
  }

  @override
  Component buildBody(Page page, Component child) {
    return div(classes: 'home', [
      div(classes: 'home-header', [header]),
      main_([
        section(classes: 'home-hero home-frame', [
          div(classes: 'home-hero-text', [
            h1([Component.text('Your Dart, refracted.')]),
            p(classes: 'home-lead', [
              Component.text(
                'Anyone with your compiled Dart app can read its class names, its strings '
                'and the shape of its logic. Refractor rewrites all three as your program '
                'compiles, and leaves what it does untouched.',
              ),
            ]),
            div(classes: 'home-actions', [
              a(classes: 'home-btn home-btn-primary', href: '/guide/quickstart', [
                Component.text('Get started  →'),
              ]),
              a(classes: 'home-btn', href: '/guide', [Component.text('Read the docs')]),
            ]),
            p(classes: 'home-note', [
              Component.text(
                'Early preview for Dart command-line and server apps, on Dart 3.11.3. '
                'Flutter support is on the way.',
              ),
            ]),
            div(classes: 'home-install', [
              code([Component.text(_install)]),
              CopyCodeButton(text: _install),
            ]),
          ]),
          const HeroSlider(),
        ]),
        section(classes: 'home-demo home-frame', [
          div(classes: 'home-demo-head', [
            h2([Component.text('One class, pass by pass')]),
            p([
              Component.text(
                'Switch passes on and off and watch the same class change. Opaque predicates, '
                'bogus control flow and call indirection are in the ',
              ),
              a(href: '/rulebook', [Component.text('Rulebook')]),
              Component.text('.'),
            ]),
          ]),
          const Playground(),
        ]),
        _splitBeam(),
        section(classes: 'home-why home-frame', [
          h2([Component.text('Harder to read, still yours to debug')]),
          ul(classes: 'home-points', [
            _point(
              'Renames you can trust',
              'Refractor works after the Dart compiler has resolved every call and override, '
                  "so a renamed method is renamed everywhere it's used. Your source files are "
                  'never touched.',
              href: '/architecture',
              more: 'How it works',
            ),
            _point(
              'Nine passes, one file',
              'Each pass is one line in refractor.yaml. Give it a seed and every build comes '
                  'out the same.',
              href: '/rulebook',
              more: 'Browse the Rulebook',
            ),
            _point(
              'Crash reports you can still read',
              'Each build writes a private symbol map. Give a crash trace to refractor '
                  'symbolicate and your own names come back.',
              href: '/recipes/symbolication',
              more: 'Debugging with the symbol map',
            ),
          ]),
        ]),
        section(classes: 'home-cta', [
          div(classes: 'home-cta-inner home-frame', [
            h2([Component.text('Your first obfuscated build')]),
            div(classes: 'home-cta-text', [
              p([
                Component.text(
                  'Three commands: install the CLI, generate a config, build. The '
                  'Quickstart walks a fresh console app through them in about five minutes.',
                ),
              ]),
              a(classes: 'home-btn home-btn-primary', href: '/guide/quickstart', [
                Component.text('Open the Quickstart  →'),
              ]),
            ]),
            _commands(const [_install, 'refractor init', 'refractor build']),
          ]),
        ]),
        child,
      ]),
      footer(classes: 'home-footer home-frame', [
        a(classes: 'home-footer-mark', href: '/', [
          img(classes: 'brand-on-light', src: '/images/refractor-wordmark-light.svg', alt: 'Refractor'),
          img(classes: 'brand-on-dark', src: '/images/refractor-wordmark-dark.svg', alt: 'Refractor'),
        ]),
        div(classes: 'home-footer-row', [
          nav(
            classes: 'home-footer-links',
            attributes: {'aria-label': 'Site'},
            [
              a(href: '/guide', [Component.text('Docs')]),
              a(href: '/guide/quickstart', [Component.text('Quickstart')]),
              a(href: '/rulebook', [Component.text('Rulebook')]),
              a(href: '/recipes', [Component.text('Recipes')]),
              a(href: 'https://github.com/yardexx/refractor', [Component.text('GitHub')]),
            ],
          ),
          p([
            Component.text('MIT licensed and in early development. Built with '),
            a(href: 'https://jaspr.site', [Component.text('jaspr')]),
            Component.text('.'),
          ]),
        ]),
      ]),
    ]);
  }

  /// A beam across the page that meets a small prism and leaves as the nine
  /// pass colors: the hero's picture again, at the scale of a divider.
  Component _splitBeam() {
    final n = rulebookPasses.length;
    String f(double v) => v.toStringAsFixed(2);
    final rays = [
      for (final (i, pass) in rulebookPasses.indexed)
        '<path class="ray-${pass.slug}" d="M0 ${f(13 + i / n)}L100 ${f(i * 3.0)}'
            'L100 ${f(i * 3.0 + 3)}L0 ${f(13 + (i + 1) / n)}Z"/>',
    ];
    return div(
      classes: 'home-split',
      attributes: {'aria-hidden': 'true'},
      [
        span(classes: 'home-split-beam', []),
        span(classes: 'home-split-prism prism-mark', []),
        RawText('<svg class="home-split-rays" viewBox="0 0 100 27" preserveAspectRatio="none">${rays.join()}</svg>'),
      ],
    );
  }

  Component _point(String title, String body, {required String href, required String more}) {
    return li(classes: 'home-point', [
      h3([
        span(classes: 'prism-mark', []),
        Component.text(title),
      ]),
      p([Component.text(body)]),
      a(href: href, [Component.text('$more  →')]),
    ]);
  }

  /// The first commands, in the docs' code panel with a copy button.
  Component _commands(List<String> lines) {
    return div(classes: 'cb cb-sh', [
      div(classes: 'cb-head', [
        span(classes: 'cb-lang', [Component.text('Shell')]),
        CopyCodeButton(text: lines.join('\n')),
      ]),
      pre(classes: 'cb-code', [
        code([
          for (final line in lines)
            span(classes: 'cb-line cb-cmd', [
              span(classes: 'tk-id', [Component.text(line)]),
            ]),
        ]),
      ]),
    ]);
  }
}

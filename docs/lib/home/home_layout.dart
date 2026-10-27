import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'playground.dart';

/// The landing page: a hero, the pass [Playground], and a short pitch.
///
/// Selected with `layout: home`. Styles live in `web/styles/home.css`.
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
    yield link(rel: 'stylesheet', href: '/styles/home.css');
  }

  @override
  Component buildBody(Page page, Component child) {
    return div(classes: 'home', [
      div(classes: 'home-header', [header]),
      main_([
        section(classes: 'home-hero', [
          img(classes: 'home-icon', src: '/images/refractor-icon.svg', alt: ''),
          span(classes: 'home-pill', [
            span(classes: 'home-pill-dot', []),
            Component.text('Early preview · Dart 3.11.3'),
          ]),
          h1([
            Component.text('Your Dart, '),
            span(classes: 'home-grad', [Component.text('refracted.')]),
          ]),
          p(classes: 'home-lead', [
            Component.text(
              'Refractor obfuscates compiled Dart at the kernel level. It renames '
              'identifiers, encrypts literals and scrambles control flow, then hands '
              'back a binary that behaves exactly like the original.',
            ),
          ]),
          div(classes: 'home-actions', [
            a(classes: 'home-btn home-btn-primary', href: '/guide/quickstart', [
              Component.text('Get started  →'),
            ]),
            a(classes: 'home-btn', href: '/guide', [Component.text('Read the docs')]),
          ]),
          code(classes: 'home-install', [
            span(classes: 'home-install-prompt', [Component.text(r'$ ')]),
            Component.text('dart pub global activate --source git https://github.com/yardexx/refractor.git'),
          ]),
        ]),
        section(classes: 'home-demo', [
          p(classes: 'home-demo-hint', [
            Component.text('Toggle a pass to see what it does to the same class. '),
            a(href: '/rulebook', [Component.text('What each pass does →')]),
          ]),
          const Playground(),
        ]),
        section(classes: 'home-features', [
          _feature(
            'Works on kernel, not source',
            'Refractor rewrites the .dill the Dart front end produces, where every type, '
                'call target and override is already resolved. Renames stay correct, and '
                'your source never changes.',
            href: '/architecture',
            more: 'How it works',
          ),
          _feature(
            'Nine passes, one YAML file',
            'Rename, encrypt, mangle, flatten and more. Each pass is a line in '
                'refractor.yaml, with a seed for reproducible builds.',
            href: '/rulebook',
            more: 'Browse the Rulebook',
          ),
          _feature(
            'Reversible, but only for you',
            'Every build writes a private symbol map, and refractor symbolicate turns an '
                'obfuscated crash trace back into your own names.',
            href: '/recipes/symbolication',
            more: 'Debugging with the symbol map',
          ),
        ]),
        section(classes: 'home-cta', [
          h2([Component.text('Ship your first obfuscated build in five minutes.')]),
          a(classes: 'home-btn home-btn-primary', href: '/guide/quickstart', [
            Component.text('Open the Quickstart  →'),
          ]),
        ]),
        child,
      ]),
      footer(classes: 'home-footer', [
        span([Component.text('Refractor is MIT licensed and in early development.')]),
        span([
          a(href: 'https://github.com/yardexx/refractor', [Component.text('GitHub')]),
          Component.text(' · Built with '),
          a(href: 'https://jaspr.site', [Component.text('jaspr')]),
        ]),
      ]),
    ]);
  }

  Component _feature(String title, String body, {required String href, required String more}) {
    return div(classes: 'home-feature', [
      h3([Component.text(title)]),
      p([Component.text(body)]),
      a(href: href, [Component.text('$more  →')]),
    ]);
  }
}

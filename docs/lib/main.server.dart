/// The entrypoint for the **server** environment.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/github_button.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/components/sidebar.dart';
import 'package:jaspr_content/components/sidebar_toggle_button.dart';
import 'package:jaspr_content/components/tabs.dart';
import 'package:jaspr_content/components/theme_toggle.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'components/brand_header.dart';
import 'components/cards.dart';
import 'components/code_panel.dart';
import 'components/pass_compare.dart';
import 'diagrams/diagram_components.dart';
import 'home/home_layout.dart';
import 'main.server.options.dart';
import 'rulebook/rulebook_components.dart';

BrandHeader _header({required bool docs}) => BrandHeader(
  // The landing page has no sidebar to toggle, but links into the docs.
  leading: docs ? const [SidebarToggleButton()] : const [],
  items: [
    if (!docs) a(classes: 'header-link', href: '/guide', [Component.text('Docs')]),
    ThemeToggle(),
    GitHubButton(repo: 'yardexx/refractor'),
  ],
);

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    ContentApp(
      templateEngine: MustacheTemplateEngine(),
      parsers: [MarkdownParser()],
      extensions: [HeadingAnchorsExtension(), TableOfContentsExtension()],
      components: [
        Callout(),
        const CodePanel(),
        Image(zoom: true),
        const Tabs(),
        PassCompare(),
        const Cards(),
        const Card(),
        // Rulebook pass pages.
        const PassFacts(),
        const PassPager(),
        const PassGrid(),
        const Guarantees(),
        const Promises(),
        const Caveats(),
        // Architecture diagrams.
        const Diagrams(),
      ],
      layouts: [
        const EmptyLayout(),
        HomeLayout(header: _header(docs: false)),
        DocsLayout(
          header: _header(docs: true),
          sidebar: Sidebar(
            groups: [
              SidebarGroup(
                links: [
                  SidebarLink(text: 'Introduction', href: '/guide'),
                  SidebarLink(text: 'Quickstart', href: '/guide/quickstart'),
                ],
              ),
              SidebarGroup(
                title: 'Guide',
                links: [
                  SidebarLink(text: 'Commands', href: '/guide/commands'),
                  SidebarLink(
                    text: 'Configuration',
                    href: '/guide/configuration',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Architecture',
                links: [
                  SidebarLink(text: 'Overview', href: '/architecture'),
                  SidebarLink(text: 'Passes', href: '/architecture/passes'),
                  SidebarLink(text: 'Policy', href: '/architecture/policy'),
                  SidebarLink(
                    text: 'kernel_toolkit',
                    href: '/architecture/kernel-toolkit',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Rulebook',
                links: [
                  SidebarLink(text: 'Overview', href: '/rulebook'),
                  SidebarLink(text: 'Rename', href: '/rulebook/rename'),
                  SidebarLink(
                    text: 'String encryption',
                    href: '/rulebook/string-encryption',
                  ),
                  SidebarLink(
                    text: 'Integer encryption',
                    href: '/rulebook/int-encryption',
                  ),
                  SidebarLink(
                    text: 'Arithmetic mangling',
                    href: '/rulebook/arithmetic-mangling',
                  ),
                  SidebarLink(
                    text: 'Opaque predicates',
                    href: '/rulebook/opaque-predicates',
                  ),
                  SidebarLink(
                    text: 'Control-flow flattening',
                    href: '/rulebook/control-flow-flatten',
                  ),
                  SidebarLink(text: 'Dead code', href: '/rulebook/dead-code'),
                  SidebarLink(
                    text: 'Bogus control flow',
                    href: '/rulebook/bogus-control-flow',
                  ),
                  SidebarLink(
                    text: 'Call indirection',
                    href: '/rulebook/call-indirection',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Recipes',
                links: [
                  SidebarLink(text: 'Overview', href: '/recipes'),
                  SidebarLink(
                    text: 'Continuous integration',
                    href: '/recipes/ci',
                  ),
                  SidebarLink(
                    text: 'Symbol map',
                    href: '/recipes/symbolication',
                  ),
                  SidebarLink(text: 'Flutter apps', href: '/recipes/flutter'),
                ],
              ),
            ],
          ),
        ),
      ],
      // Ink on ground: color is kept for the passes (web/styles/site.css), so
      // the theme's primary is the ink itself.
      theme: ContentTheme(
        primary: ThemeColor(ThemeColors.zinc.$900, dark: ThemeColors.zinc.$100),
        background: ThemeColor(
          ThemeColors.slate.$50,
          dark: ThemeColors.zinc.$950,
        ),
        colors: [ContentColors.quoteBorders.apply(ThemeColors.zinc.$400)],
        font: FontFamily.list([
          FontFamily('Schibsted Grotesk'),
          FontFamilies.uiSansSerif,
          FontFamilies.systemUi,
          FontFamilies.sansSerif,
        ]),
        codeFont: FontFamily.list([
          FontFamily('JetBrains Mono'),
          FontFamilies.uiMonospace,
          FontFamily('Menlo'),
          FontFamilies.monospace,
        ]),
        typography: ContentTypography.base.apply(
          styles: Styles(fontSize: 1.0625.rem, lineHeight: 1.65.em),
        ),
      ),
    ),
  );
}

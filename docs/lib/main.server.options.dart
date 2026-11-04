// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:docs/components/copy_code_button.dart' as _copy_code_button;
import 'package:docs/diagrams/blocks_diagram.dart' as _blocks_diagram;
import 'package:docs/diagrams/pipeline_diagram.dart' as _pipeline_diagram;
import 'package:docs/diagrams/policy_explorer.dart' as _policy_explorer;
import 'package:docs/diagrams/stages_diagram.dart' as _stages_diagram;
import 'package:docs/home/playground.dart' as _playground;
import 'package:docs/rulebook/copy_chip.dart' as _copy_chip;
import 'package:docs/rulebook/pass_animation.dart' as _pass_animation;
import 'package:jaspr_content/components/_internal/tab_bar.dart' as _tab_bar;
import 'package:jaspr_content/components/_internal/zoomable_image.dart'
    as _zoomable_image;
import 'package:jaspr_content/components/callout.dart' as _callout;
import 'package:jaspr_content/components/github_button.dart' as _github_button;
import 'package:jaspr_content/components/image.dart' as _image;
import 'package:jaspr_content/components/sidebar_toggle_button.dart'
    as _sidebar_toggle_button;
import 'package:jaspr_content/components/tabs.dart' as _tabs;
import 'package:jaspr_content/components/theme_toggle.dart' as _theme_toggle;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _copy_code_button.CopyCodeButton:
        ClientTarget<_copy_code_button.CopyCodeButton>(
          'copy_code_button',
          params: __copy_code_buttonCopyCodeButton,
        ),
    _blocks_diagram.BlocksDiagram: ClientTarget<_blocks_diagram.BlocksDiagram>(
      'blocks_diagram',
    ),
    _pipeline_diagram.PipelineDiagram:
        ClientTarget<_pipeline_diagram.PipelineDiagram>('pipeline_diagram'),
    _policy_explorer.PolicyExplorer:
        ClientTarget<_policy_explorer.PolicyExplorer>('policy_explorer'),
    _stages_diagram.StagesDiagram: ClientTarget<_stages_diagram.StagesDiagram>(
      'stages_diagram',
    ),
    _playground.Playground: ClientTarget<_playground.Playground>('playground'),
    _copy_chip.CopyChip: ClientTarget<_copy_chip.CopyChip>(
      'copy_chip',
      params: __copy_chipCopyChip,
    ),
    _pass_animation.PassAnimation: ClientTarget<_pass_animation.PassAnimation>(
      'pass_animation',
      params: __pass_animationPassAnimation,
    ),
    _tab_bar.TabBar: ClientTarget<_tab_bar.TabBar>(
      'jaspr_content:tab_bar',
      params: __tab_barTabBar,
    ),
    _zoomable_image.ZoomableImage: ClientTarget<_zoomable_image.ZoomableImage>(
      'jaspr_content:zoomable_image',
      params: __zoomable_imageZoomableImage,
    ),
    _github_button.GitHubButton: ClientTarget<_github_button.GitHubButton>(
      'jaspr_content:github_button',
      params: __github_buttonGitHubButton,
    ),
    _sidebar_toggle_button.SidebarToggleButton:
        ClientTarget<_sidebar_toggle_button.SidebarToggleButton>(
          'jaspr_content:sidebar_toggle_button',
        ),
    _theme_toggle.ThemeToggle: ClientTarget<_theme_toggle.ThemeToggle>(
      'jaspr_content:theme_toggle',
    ),
  },
  styles: () => [
    ..._callout.Callout.styles,
    ..._github_button.GitHubButton.styles,
    ..._image.Image.styles,
    ..._tabs.Tabs.styles,
    ..._theme_toggle.ThemeToggleState.styles,
    ..._tab_bar.TabBar.styles,
    ..._zoomable_image.ZoomableImage.styles,
  ],
);

Map<String, Object?> __copy_code_buttonCopyCodeButton(
  _copy_code_button.CopyCodeButton c,
) => {'text': c.text};
Map<String, Object?> __copy_chipCopyChip(_copy_chip.CopyChip c) => {
  'text': c.text,
};
Map<String, Object?> __pass_animationPassAnimation(
  _pass_animation.PassAnimation c,
) => {'pass': c.pass};
Map<String, Object?> __tab_barTabBar(_tab_bar.TabBar c) => {
  'initialValue': c.initialValue,
  'items': c.items,
};
Map<String, Object?> __zoomable_imageZoomableImage(
  _zoomable_image.ZoomableImage c,
) => {'src': c.src, 'alt': c.alt, 'caption': c.caption};
Map<String, Object?> __github_buttonGitHubButton(
  _github_button.GitHubButton c,
) => {'repo': c.repo};

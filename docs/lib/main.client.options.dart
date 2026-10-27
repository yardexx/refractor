// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:docs/components/copy_code_button.dart'
    deferred as _copy_code_button;
import 'package:docs/components/pass_compare_card.dart'
    deferred as _pass_compare_card;
import 'package:docs/diagrams/blocks_diagram.dart' deferred as _blocks_diagram;
import 'package:docs/diagrams/pipeline_diagram.dart'
    deferred as _pipeline_diagram;
import 'package:docs/diagrams/policy_explorer.dart'
    deferred as _policy_explorer;
import 'package:docs/diagrams/stages_diagram.dart' deferred as _stages_diagram;
import 'package:docs/home/playground.dart' deferred as _playground;
import 'package:docs/rulebook/copy_chip.dart' deferred as _copy_chip;
import 'package:jaspr_content/components/_internal/tab_bar.dart'
    deferred as _tab_bar;
import 'package:jaspr_content/components/_internal/zoomable_image.dart'
    deferred as _zoomable_image;
import 'package:jaspr_content/components/github_button.dart'
    deferred as _github_button;
import 'package:jaspr_content/components/sidebar_toggle_button.dart'
    deferred as _sidebar_toggle_button;
import 'package:jaspr_content/components/theme_toggle.dart'
    deferred as _theme_toggle;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'copy_code_button': ClientLoader(
      (p) => _copy_code_button.CopyCodeButton(text: p['text'] as String),
      loader: _copy_code_button.loadLibrary,
    ),
    'pass_compare_card': ClientLoader(
      (p) => _pass_compare_card.PassCompareCard(
        pass: p['pass'] as String,
        before: p['before'] as String,
        after: p['after'] as String,
      ),
      loader: _pass_compare_card.loadLibrary,
    ),
    'blocks_diagram': ClientLoader(
      (p) => _blocks_diagram.BlocksDiagram(),
      loader: _blocks_diagram.loadLibrary,
    ),
    'pipeline_diagram': ClientLoader(
      (p) => _pipeline_diagram.PipelineDiagram(),
      loader: _pipeline_diagram.loadLibrary,
    ),
    'policy_explorer': ClientLoader(
      (p) => _policy_explorer.PolicyExplorer(),
      loader: _policy_explorer.loadLibrary,
    ),
    'stages_diagram': ClientLoader(
      (p) => _stages_diagram.StagesDiagram(),
      loader: _stages_diagram.loadLibrary,
    ),
    'playground': ClientLoader(
      (p) => _playground.Playground(),
      loader: _playground.loadLibrary,
    ),
    'copy_chip': ClientLoader(
      (p) => _copy_chip.CopyChip(text: p['text'] as String),
      loader: _copy_chip.loadLibrary,
    ),
    'jaspr_content:tab_bar': ClientLoader(
      (p) => _tab_bar.TabBar(
        initialValue: p['initialValue'] as String,
        items: (p['items'] as Map<String, Object?>).cast<String, String>(),
      ),
      loader: _tab_bar.loadLibrary,
    ),
    'jaspr_content:zoomable_image': ClientLoader(
      (p) => _zoomable_image.ZoomableImage(
        src: p['src'] as String,
        alt: p['alt'] as String?,
        caption: p['caption'] as String?,
      ),
      loader: _zoomable_image.loadLibrary,
    ),
    'jaspr_content:github_button': ClientLoader(
      (p) => _github_button.GitHubButton(repo: p['repo'] as String),
      loader: _github_button.loadLibrary,
    ),
    'jaspr_content:sidebar_toggle_button': ClientLoader(
      (p) => _sidebar_toggle_button.SidebarToggleButton(),
      loader: _sidebar_toggle_button.loadLibrary,
    ),
    'jaspr_content:theme_toggle': ClientLoader(
      (p) => _theme_toggle.ThemeToggle(),
      loader: _theme_toggle.loadLibrary,
    ),
  },
);

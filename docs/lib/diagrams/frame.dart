import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The card every diagram sits in: a small title and, for diagrams that tour
/// their states, a play/pause button.
Component diagramFrame({
  required String title,
  required String classes,
  required List<Component> children,
  bool playing = false,
  VoidCallback? onTogglePlay,
}) {
  return div(classes: 'dg $classes', [
    div(classes: 'dg-head', [
      span(classes: 'dg-title', [Component.text(title)]),
      if (onTogglePlay != null)
        button(
          classes: 'dg-play',
          attributes: {'aria-label': playing ? 'Pause the tour' : 'Play the tour'},
          onClick: onTogglePlay,
          [Component.text(playing ? '❚❚  Pause' : '▶  Play')],
        ),
    ]),
    ...children,
  ]);
}

/// A step's detail panel. Keyed by [id] so it re-mounts, and fades in, when
/// the step changes.
Component detailPanel({required String id, required List<Component> children}) {
  return div(key: ValueKey(id), classes: 'dg-detail', children);
}

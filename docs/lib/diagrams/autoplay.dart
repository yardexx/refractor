import 'dart:async';

import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

/// Steps a diagram through its states on a timer until the reader takes over.
///
/// Clicking a state ([goTo]) stops the tour; [togglePlay] resumes it. The
/// tour doesn't start for readers who prefer reduced motion.
mixin Autoplay<T extends StatefulComponent> on State<T> {
  int step = 0;
  bool playing = false;
  Timer? _timer;

  int get stepCount;

  Duration get interval => const Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !web.window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    playing = true;
    _timer = Timer.periodic(interval, (_) => setState(() => step = (step + 1) % stepCount));
  }

  void goTo(int index) {
    _timer?.cancel();
    setState(() {
      playing = false;
      step = index;
    });
  }

  void togglePlay() {
    if (playing) {
      _timer?.cancel();
      setState(() => playing = false);
    } else {
      setState(_start);
    }
  }
}

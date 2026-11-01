import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/lokal_performance_scope.dart';

/// An edge-to-edge push between the four main tabs.
///
/// The former AnimatedSwitcher painted the new tab *over* the old one. Even
/// with larger translations the old surface remained visibly ghosted behind
/// the incoming content. This implementation gives both screens a single,
/// synchronized position on a horizontal strip: their edges touch but NEVER
/// overlap, so there is no translucent layer, crossfade or dark gap.
///
/// Only one outgoing tab exists for the duration of the animation. No tabs
/// remain cached after completion.
class LokalNavigationSwitcher extends StatefulWidget {
  const LokalNavigationSwitcher({
    super.key,
    required this.child,
    this.direction = 1,
  });

  /// Each destination must carry its stable identity key.
  final Widget child;

  /// +1 for moving to a tab on the right; -1 for a tab on the left.
  final int direction;

  static const enterDuration = Duration(milliseconds: 330);
  static const curve = Cubic(.2, 0, 0, 1);

  @override
  State<LokalNavigationSwitcher> createState() => _LokalNavigationSwitcherState();
}

class _LokalNavigationSwitcherState extends State<LokalNavigationSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  Widget? _outgoing;
  int _travel = 1;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: LokalNavigationSwitcher.enterDuration,
      value: 1,
    )..addStatusListener(_onAnimationStatus);
  }

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      AppConstants.animationNormal == Duration.zero ||
      LokalPerformanceScope.of(context);

  @override
  void didUpdateWidget(covariant LokalNavigationSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key == widget.child.key) return;

    _travel = widget.direction < 0 ? -1 : 1;
    if (_reduceMotion) {
      _outgoing = null;
      _progress.value = 1;
    } else {
      // Replacing a rapidly interrupted transition discards the older
      // outgoing tree. At most two destination trees can be mounted.
      _outgoing = oldWidget.child;
      _progress.forward(from: 0);
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void dispose() {
    _progress
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    final animating = _outgoing != null && !reduceMotion;
    final direction =
        (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0) *
        _travel;

    // Keep this exact Stack/AnimatedBuilder ancestry even when idle.
    // Reparenting a KeyedSubtree from a bare child to a different wrapper
    // on every navigation would dispose/recreate heavy Home state.
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (animating)
            AnimatedBuilder(
              key: ValueKey(_outgoing!.key),
              animation: _progress,
              child: _outgoing,
              builder: (context, outgoing) {
                final progress = LokalNavigationSwitcher.curve
                    .transform(_progress.value);
                return IgnorePointer(
                  ignoring: true,
                  child: ExcludeSemantics(
                    child: TickerMode(
                      enabled: false,
                      child: FractionalTranslation(
                        translation: Offset(-direction * progress, 0),
                        child: RepaintBoundary(child: outgoing!),
                      ),
                    ),
                  ),
                );
              },
            ),
          AnimatedBuilder(
            key: ValueKey(widget.child.key),
            animation: _progress,
            child: widget.child,
            builder: (context, incoming) {
              final progress = animating
                  ? LokalNavigationSwitcher.curve.transform(_progress.value)
                  : 1.0;
              return FractionalTranslation(
                translation: Offset(direction * (1 - progress), 0),
                child: RepaintBoundary(child: incoming!),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/lokal_performance_scope.dart';

/// Only two tab trees are present for the duration of a tab change.
///
/// A new tab can be expensive to build (large library, online catalogue).
/// Dropping the old tab immediately shows an empty/black navigator before the
/// new one has painted. This switcher keeps the old scene visible, stops its
/// tickers and input, then disposes it after a short slide. It intentionally
/// does NOT keep every destination alive like IndexedStack.
class LokalNavigationSwitcher extends StatelessWidget {
  const LokalNavigationSwitcher({super.key, required this.child});

  /// Supply a different [Key] for each destination, e.g. KeyedSubtree.
  final Widget child;

  static const enterDuration = Duration(milliseconds: 230);
  static const exitDuration = Duration(milliseconds: 210);
  static const translatePixels = 20.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        AppConstants.animationNormal == Duration.zero ||
        LokalPerformanceScope.of(context);

    return ClipRect(
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : enterDuration,
        reverseDuration: reduceMotion ? Duration.zero : exitDuration,
        switchInCurve: const Cubic(.2, 0, 0, 1),
        switchOutCurve: const Cubic(.2, 0, 0, 1),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: RepaintBoundary(child: child),
          builder: (_, cachedChild) {
            final leaving = animation.status == AnimationStatus.reverse;
            return IgnorePointer(
              ignoring: leaving,
              child: TickerMode(
                enabled: !leaving,
                child: Transform.translate(
                  offset: Offset(
                    (leaving ? -translatePixels : translatePixels) *
                        (1 - animation.value),
                    0,
                  ),
                  child: cachedChild,
                ),
              ),
            );
          },
        ),
        child: child,
      ),
    );
  }
}

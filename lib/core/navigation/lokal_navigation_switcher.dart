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
  const LokalNavigationSwitcher({
    super.key,
    required this.child,
    this.direction = 1,
  });

  /// Supply a different [Key] for each destination, e.g. KeyedSubtree.
  final Widget child;

  /// 1: next tab to the right; -1: previous tab to the left.
  final int direction;

  static const enterDuration = Duration(milliseconds: 330);
  static const exitDuration = Duration(milliseconds: 310);
  // PixelPlayer-style directional navigation; both routes remain overlapping.
  static const enterFraction = .48;
  static const exitFraction = .22;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        AppConstants.animationNormal == Duration.zero ||
        LokalPerformanceScope.of(context);

    final direction = (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0) *
        (this.direction < 0 ? -1.0 : 1.0);

    return ClipRect(
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : enterDuration,
        reverseDuration: reduceMotion ? Duration.zero : exitDuration,
        switchInCurve: const Cubic(.2, 0, 0, 1),
        switchOutCurve: const Cubic(.2, 0, 0, 1),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.center,
          children: [
            if (previousChildren.isNotEmpty) previousChildren.last,
            ?currentChild,
          ],
        ),
        transitionBuilder: (child, animation) => AnimatedBuilder(
          animation: animation,
          child: RepaintBoundary(child: child),
          builder: (_, cachedChild) {
            final leaving = animation.status == AnimationStatus.reverse;
            return IgnorePointer(
              ignoring: leaving,
              child: TickerMode(
                enabled: !leaving,
                child: FractionalTranslation(
                  // Unlike the old 20px overlap, this gives Home, Library
                  // and Search a clear direction. Neither screen fades or
                  // changes opacity; there is always visible overlap.
                  translation: Offset(
                    (leaving ? -exitFraction : enterFraction) *
                        direction * (1 - animation.value),
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

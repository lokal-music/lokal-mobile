import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/lokal_performance_scope.dart';

/// PixelPlayer-inspired shared-axis motion for normal push / pop operations.
///
/// Both route animations matter: [animation] animates the new/removed page,
/// and [secondaryAnimation] sends the page beneath it into the background.
/// Keeping this implementation on the theme covers ordinary MaterialPageRoute
/// pushes, including their toolbar Back actions.
///
/// Android uses Flutter's native predictive-back renderer as the inner layer:
/// the interactive edge-swipe progress and cancellation are owned by Flutter,
/// rather than competing with Android's gesture recognizer.
class LokalPageMotion extends PageTransitionsBuilder {
  const LokalPageMotion({this.androidPredictiveBack = false});

  final bool androidPredictiveBack;

  static const Duration duration = Duration(milliseconds: 360);
  static const Duration reverseDuration = Duration(milliseconds: 320);
  static const Curve emphasized = Cubic(.2, 0, 0, 1);
  static const Curve popEase = Cubic(.3, 0, .8, .15);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context) ||
        AppConstants.animationNormal == Duration.zero) {
      return child;
    }

    // Avoid animated full-page opacity layers on low-memory/performance mode.
    final performance = LokalPerformanceScope.of(context);
    final direction = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final primary = CurvedAnimation(
      parent: animation,
      curve: emphasized,
      reverseCurve: popEase,
    );
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: emphasized,
      reverseCurve: emphasized,
    );

    // Android's predictive-back transition listens to gesture progress and
    // handles cancel / commit. Surround it with lightweight transforms, not
    // another gesture recognizer or a manual Navigator.pop on drag completion.
    final native = androidPredictiveBack
        ? const PredictiveBackPageTransitionsBuilder().buildTransitions(
            route, context, animation, secondaryAnimation, child)
        : child;

    // New page arrives from the leading edge; on Back it returns there.
    final foreground = SlideTransition(
      position: Tween<Offset>(
        begin: Offset(.22 * direction, 0),
        end: Offset.zero,
      ).animate(primary),
      child: performance || androidPredictiveBack
          ? native
          : FadeTransition(
              opacity: primary,
              child: ScaleTransition(
                scale: Tween<double>(begin: .965, end: 1).animate(primary),
                child: native,
              ),
            ),
    );

    // The previous page recedes gently on push; it re-emerges toward the
    // finger on pop. Animated using the *secondary* animation on that route.
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-.14 * direction, 0),
      ).animate(secondary),
      child: performance || androidPredictiveBack
          ? foreground
          : ScaleTransition(
              scale: Tween<double>(begin: 1, end: .965).animate(secondary),
              child: foreground,
            ),
    );
  }
}

/// Consistent timing for the shell's library/detail routes. This remains a
/// MaterialPageRoute so Flutter's native Android predictive back and Hero
/// machinery can participate (unlike a custom PageRouteBuilder transition).
class LokalPageRoute<T> extends MaterialPageRoute<T> {
  LokalPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => AppConstants.animationNormal == Duration.zero
      ? Duration.zero
      : LokalPageMotion.duration;

  @override
  Duration get reverseTransitionDuration =>
      AppConstants.animationNormal == Duration.zero
          ? Duration.zero
          : LokalPageMotion.reverseDuration;
}

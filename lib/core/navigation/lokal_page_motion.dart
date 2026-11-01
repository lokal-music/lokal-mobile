import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/lokal_performance_scope.dart';

/// Whether the system asks the app to avoid motion.
bool systemRequestsReducedMotion(BuildContext context) {
  final accessibility =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return MediaQuery.disableAnimationsOf(context) ||
      accessibility.disableAnimations ||
      accessibility.reduceMotion;
}

/// A single, opacity-free shared-axis motion for all ordinary Lokal routes.
///
/// The old implementation nested Flutter's Android predictive-back builder
/// (which uses FadeForwards outside a gesture) *inside* our own fade, scale
/// and slide. At the start of a push the new page was transparent while the
/// old page had already shifted, exposing the navigator's dark background.
/// It also asked the GPU to composite multiple translucent full-screen layers.
///
/// Here the incoming route is opaque from its very first frame. The previous
/// route is kept mounted by Navigator and moves only a small distance in the
/// opposite direction. There is always overlap, so neither forward nor
/// reverse travel can reveal an unpainted strip of the underlying navigator.
/// Hero flights and specialized player/queue sheet routes remain separate.
class LokalPageMotion extends PageTransitionsBuilder {
  const LokalPageMotion();

  /// A fast, predictable motion profile; no long fade-in or black scrim.
  static const duration = Duration(milliseconds: 320);
  static const reverseDuration = Duration(milliseconds: 285);
  static const enterOffset = .34;
  // A pop must slide until the outgoing page is entirely past the edge,
  // rather than removing it after the same short push distance.
  static const exitOffset = 1.0;
  static const behindOffset = -.10;
  static const enterCurve = Cubic(.2, 0, 0, 1);
  static const backCurve = Cubic(.23, .65, .3, 1);

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

    // The translation is directional. Do not introduce a second opacity
    // compositing pass or a scale that would expose the underlying backdrop.
    final direction = Directionality.of(context) == TextDirection.rtl
        ? -1.0
        : 1.0;

    final backgroundProgress = CurvedAnimation(
      parent: secondaryAnimation,
      curve: enterCurve,
      reverseCurve: backCurve,
    );

    // This builder *must* read animation.status on every frame. A tween
    // selected only in buildTransitions would be frozen at push time and pop
    // would still stop after 34% of the viewport, producing the exact
    // half-dismiss seen in the device recording.
    final incoming = AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (context, paintedPage) {
        final returning = animation.status == AnimationStatus.reverse;
        final curved = (returning ? backCurve : enterCurve)
            .transform(animation.value.clamp(0.0, 1.0));
        return FractionalTranslation(
          translation: Offset(
            (returning ? exitOffset : enterOffset) *
                direction * (1 - curved),
            0,
          ),
          child: paintedPage!,
        );
      },
    );

    // Ultra Performance Mode avoids translating/rasterizing the old page at
    // all. Its full-size, opaque backdrop remains in place behind the new
    // route; the incoming slide remains reversible and never exposes black.
    if (LokalPerformanceScope.of(context)) return incoming;

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: Offset(behindOffset * direction, 0),
      ).animate(backgroundProgress),
      child: incoming,
    );
  }
}

/// A native Material route keeps Navigator, Hero and Android system Back
/// semantics, unlike an independently composited PageRouteBuilder.
/// Android's system Back still commits through the nested NavigatorPopHandler.
/// Gesture-progress rendering must be evaluated separately on device.
class LokalPageRoute<T> extends MaterialPageRoute<T> {
  LokalPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration =>
      AppConstants.animationNormal == Duration.zero
          ? Duration.zero
          : LokalPageMotion.duration;

  @override
  Duration get reverseTransitionDuration =>
      AppConstants.animationNormal == Duration.zero
          ? Duration.zero
          : LokalPageMotion.reverseDuration;
}

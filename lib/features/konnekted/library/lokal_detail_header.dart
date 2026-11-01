import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/widgets/lokal/lokal_glass.dart';

/// The artist and album headers share chrome, but not artwork treatment:
/// artists get a photographic canvas; albums get an actual framed cover.
/// This avoids stretching square covers across an entire phone display.
class LokalDetailHeader extends StatelessWidget {
  const LokalDetailHeader({
    super.key,
    required this.title,
    required this.artwork,
    required this.isArtist,
    required this.background,
    required this.onBack,
    required this.onArtworkTap,
    required this.onOnline,
    required this.onlineEnabled,
    this.onlineLoading = false,
    this.onlineDisabled = false,
    required this.onMore,
    this.artistCredit,
    this.metadata,
    this.artworkHeroTag,
  });

  final String title;
  final Widget artwork;
  final Widget? artistCredit;
  final String? metadata;
  final String? artworkHeroTag;
  final bool isArtist;
  final Color background;
  final VoidCallback onBack, onOnline, onMore, onArtworkTap;
  final bool onlineEnabled;
  final bool onlineLoading;
  final bool onlineDisabled;

  /// Match the pull-down artwork to the foreground artist header's extent.
  static double artistHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    return (size.height * .52 + (scale - 1) * 90)
        .clamp(350.0, 580.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lokal;
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final topInset = MediaQuery.paddingOf(context).top;
    final artSize = (size.width * (size.width > 620 ? .36 : .63))
        .clamp(184.0, 314.0);
    final heroHeight = isArtist
        ? artistHeight(context)
        : artSize + 268 + topInset + (scale - 1) * 230;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: isArtist
                    ? const Alignment(0, -.5)
                    : const Alignment(0, -.2),
                radius: 1.15,
                colors: [Color.lerp(background, t.accent, .10)!, background],
              ),
            ),
          ),
          if (isArtist) ...[
            GestureDetector(
              onTap: onArtworkTap,
              behavior: HitTestBehavior.opaque,
              child: RepaintBoundary(child: artwork),
            ),
            // A full-size decoration sits *above* the portrait. Without
            // IgnorePointer, its RenderDecoratedBox wins hit testing and
            // consumes taps before the artwork's GestureDetector can open
            // the fullscreen viewer.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Keep the portrait visible. The previous 75%-black
                  // scrim began at 63% height and its fully opaque tail
                  // created the solid dark band in the screenshot.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .68, .93, 1],
                    colors: [
                      Colors.black.withValues(alpha: .10),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .15),
                      background.withValues(alpha: .88),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            Positioned(
              top: topInset + 76,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  width: artSize,
                  height: artSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .25),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: onArtworkTap,
                    child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: artworkHeroTag == null
                        ? RepaintBoundary(child: artwork)
                        : Hero(
                            tag: artworkHeroTag!,
                            child: RepaintBoundary(child: artwork),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _headerButton(
                      context,
                      Icons.arrow_back_rounded,
                      l10n.back,
                      onBack,
                    ),
                    const Spacer(),
                    // The catalogue is a single icon-only toggle in the
                    // header. Its state is exposed to assistive technology,
                    // not as a separate label or description on the page.
                    LokalGlassButton(
                      semanticLabel: onlineEnabled
                          ? lokalText('Disable online catalogue')
                          : lokalText('Enable online catalogue'),
                      onPressed: (onlineLoading || onlineDisabled) ? null : onOnline,
                      tint: onlineEnabled
                          ? t.accent.withValues(alpha: .28)
                          : Colors.black.withValues(alpha: .16),
                      child: onlineLoading
                          ? SizedBox.square(
                              dimension: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isArtist ? Colors.white : t.text,
                              ),
                            )
                          : Icon(
                              onlineEnabled
                                  ? Icons.language_rounded
                                  : Icons.language_outlined,
                              // The active catalogue state must remain clear
                              // on both dark artwork and light album headers.
                              color: onlineEnabled
                                  ? t.accent
                                  : (isArtist ? Colors.white : t.text),
                              size: 23,
                            ),
                    ),
                    const SizedBox(width: 10),
                    _headerButton(
                      context,
                      Icons.more_horiz_rounded,
                      lokalText('More'),
                      onMore,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArtist ? 'ARTIST' : 'ALBUM',
                  style: LokalTheme.label(
                    t,
                    size: 11,
                    color: isArtist
                        ? Colors.white.withValues(alpha: .78)
                        : t.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: LokalTheme.sans,
                      fontSize: isArtist ? 43 : 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.35,
                      height: 1.06,
                      color: isArtist ? Colors.white : t.text,
                      shadows: isArtist
                          ? const [Shadow(color: Color(0x55000000), blurRadius: 5)]
                          : null,
                    ),
                  ),
                ),
                if (artistCredit != null) ...[
                  const SizedBox(height: 9),
                  artistCredit!,
                ],
                if (metadata?.isNotEmpty == true) ...[
                  const SizedBox(height: 9),
                  Text(
                    metadata!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isArtist ? Colors.white70 : t.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => LokalGlassButton(
    semanticLabel: label,
    onPressed: onTap,
    tint: Colors.black.withValues(alpha: .16),
    child: Icon(icon, color: isArtist ? Colors.white : context.lokal.text, size: 23),
  );
}


/// Artwork visible on a downward pull, only above the artist header.
/// The rest of the detail page is its usual clean, opaque surface.
class LokalDetailOverscrollBackdrop extends StatelessWidget {
  const LokalDetailOverscrollBackdrop({
    super.key,
    required this.artwork,
    required this.height,
    required this.background,
  });

  final Widget artwork;
  final double height;
  final Color background;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: 0,
    height: height,
    child: IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.12,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: artwork,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .70, 1],
                    colors: [
                      Colors.black.withValues(alpha: .12),
                      Colors.black.withValues(alpha: .15),
                      background,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

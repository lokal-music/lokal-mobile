import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A stationary, full-bleed album/artist image behind the scrollable detail
/// content. The photograph never follows the scroll offset. Its lower portion
/// transitions into the page surface instead of ending at a visible hard edge.
///
/// A clipped BackdropFilter softens only the tail of the image, matching the
/// full-player's artwork-derived blur without continuously blurring the face
/// or re-decoding a second copy of the artwork.
class LokalDetailFixedBackdrop extends StatelessWidget {
  const LokalDetailFixedBackdrop({
    super.key,
    required this.artwork,
    required this.background,
  });

  final Widget artwork;
  final Color background;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: background),
          RepaintBoundary(child: artwork),
          // Blur only the lower part of the portrait / cover. Keeping the
          // upper image untouched preserves sharp faces and album details.
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: .38,
              widthFactor: 1,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, .40, .59, .76, .90, 1],
                  colors: [
                    Colors.black.withValues(alpha: .10),
                    Colors.transparent,
                    background.withValues(alpha: .08),
                    background.withValues(alpha: .52),
                    background.withValues(alpha: .90),
                    background,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

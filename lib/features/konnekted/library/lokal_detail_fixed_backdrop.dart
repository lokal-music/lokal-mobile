import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Stationary artwork shared by artist and album detail pages. A gentle
/// artwork blur and alpha fade replace the hard boundary at the end of the
/// header. There is no darkening overlay, tint or drop shadow.
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
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .56, .72, .88, 1],
              colors: [
                Colors.white,
                Colors.white,
                Color(0xEEFFFFFF),
                Color(0x66FFFFFF),
                Colors.transparent,
              ],
            ).createShader(bounds),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: artwork),
                // A stationary, clipped backdrop filter reuses the already
                // decoded portrait/cover without a second network fetch or
                // second artwork widget. The blend toward the page color
                // hides the edge of the blurred portion.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: .38,
                    widthFactor: 1,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

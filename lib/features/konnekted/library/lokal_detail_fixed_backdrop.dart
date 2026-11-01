import 'package:flutter/material.dart';

/// Stationary album/artist art that stays sharp, with only its *bottom edge*
/// feathered into the theme background. Do not blur, tint, or darken the image:
/// blurring the last third of the picture made the transition conspicuous.
class LokalDetailFixedBackdrop extends StatelessWidget {
  const LokalDetailFixedBackdrop({
    super.key,
    required this.artwork,
    required this.background,
  });

  final Widget artwork;
  final Color background;

  /// Keep 92% of the picture fully intact; only the last 8% softens the seam.
  /// The destination is the actual page theme color underneath the image.
  @visibleForTesting
  static const edgeFeather = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0, .92, 1],
    colors: [
      Colors.white,
      Colors.white,
      Colors.transparent,
    ],
  );

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: background),
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: edgeFeather.createShader,
            child: RepaintBoundary(child: artwork),
          ),
        ],
      ),
    ),
  );
}

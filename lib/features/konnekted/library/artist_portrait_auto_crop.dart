import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Only trims confidently solid, symmetric letterbox strips. Dark portraits
/// without a sharp transition into brighter image content are left untouched.
@visibleForTesting
({int top, int bottom}) portraitBlackBars(
  ui.ByteData bytes, int width, int height,
) {
  if (width < 32 || height < 32) return (top: 0, bottom: 0);
  final pixels = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  bool blackRow(int y) {
    var dark = 0;
    const samples = 24;
    for (var i = 0; i < samples; i++) {
      final x = ((i + .5) * width / samples).floor();
      final offset = (y * width + x) * 4;
      if (pixels[offset + 3] >= 240 &&
          pixels[offset] <= 18 && pixels[offset + 1] <= 18 &&
          pixels[offset + 2] <= 18) dark++;
    }
    return dark >= 23;
  }

  // Require a large, uniformly black band on both sides; this avoids
  // clipping naturally low-key portraits or their dark gradient scrims.
  final limit = (height * .25).floor();
  var top = 0;
  var bottom = 0;
  while (top < limit && blackRow(top)) { top++; }
  while (bottom < limit && blackRow(height - bottom - 1)) { bottom++; }
  if (top < height * .035 || bottom < height * .035) {
    return (top: 0, bottom: 0);
  }
  // Don't mistake almost-black entire images for letterboxed artwork.
  bool contentVisible(int y) {
    var lit = 0;
    for (var i = 0; i < 24; i++) {
      final x = ((i + .5) * width / 24).floor();
      final offset = (y * width + x) * 4;
      if (pixels[offset] + pixels[offset + 1] + pixels[offset + 2] > 105) lit++;
    }
    return lit >= 7;
  }
  if (!contentVisible((top + height * .04).floor().clamp(0, height - 1)) &&
      !contentVisible((height - bottom - height * .04).floor().clamp(0, height - 1))) {
    return (top: 0, bottom: 0);
  }
  return (top: top, bottom: bottom);
}

/// Reuses the usual artist artwork until a conservative border check succeeds.
/// No bitmap is rewritten; fullscreen preview still receives the original.
class ArtistPortraitAutoCrop extends StatefulWidget {
  const ArtistPortraitAutoCrop({
    super.key, required this.imagePath, required this.fallback,
  });
  final String? imagePath;
  final Widget fallback;

  @override
  State<ArtistPortraitAutoCrop> createState() => _ArtistPortraitAutoCropState();
}

class _ArtistPortraitAutoCropState extends State<ArtistPortraitAutoCrop> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  Rect? _crop;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(ArtistPortraitAutoCrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _load();
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  void _load() {
    if (!mounted) return;
    final generation = ++_generation;
    _unsubscribe();
    _image?.dispose();
    _image = null;
    _crop = null;
    final path = widget.imagePath;
    if (path == null || path.isEmpty) return;
    ImageProvider provider;
    if (path.startsWith('https://') || path.startsWith('http://')) {
      provider = NetworkImage(path);
    } else if (path.startsWith('/')) {
      provider = FileImage(File(path));
    } else {
      return; // Unsupported/custom artwork path: retain normal renderer.
    }
    final stream = ResizeImage(provider, width: 768)
        .resolve(createLocalImageConfiguration(context));
    _stream = stream;
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) async {
      if (!mounted || generation != _generation) return;
      final image = info.image.clone();
      _unsubscribe();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (!mounted || generation != _generation || bytes == null) return;
        final bars = portraitBlackBars(bytes, image.width, image.height);
        if (bars.top == 0 && bars.bottom == 0) return;
        setState(() {
          _image = image.clone();
          _crop = Rect.fromLTWH(0, bars.top.toDouble(),
              image.width.toDouble(), (image.height - bars.top - bars.bottom).toDouble());
        });
      } catch (_) {
        // Invalid, partial or unavailable image: use the unchanged artwork.
      } finally {
        image.dispose();
      }
    }, onError: (_, _) => _unsubscribe());
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    ++_generation;
    _unsubscribe();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null || _crop == null) return widget.fallback;
    return CustomPaint(
      painter: _PortraitCropPainter(_image!, _crop!),
      child: const SizedBox.expand(),
    );
  }
}

class _PortraitCropPainter extends CustomPainter {
  const _PortraitCropPainter(this.image, this.crop);
  final ui.Image image;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.cover, crop.size, size);
    final source = Alignment.center.inscribe(fitted.source, crop);
    final destination = Alignment.center.inscribe(
      fitted.destination, Offset.zero & size,
    );
    canvas.drawImageRect(image, source, destination, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_PortraitCropPainter old) =>
      old.image != image || old.crop != crop;
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/konnekted/library/artist_portrait_auto_crop.dart';

ByteData portrait(int width, int height, {
  required int top, required int bottom, bool darkContent = false,
}) {
  final result = ByteData(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final border = y < top || y >= height - bottom;
      final value = border ? 0 : (darkContent ? 9 : 130);
      final offset = (y * width + x) * 4;
      result.setUint8(offset, value);
      result.setUint8(offset + 1, value);
      result.setUint8(offset + 2, value);
      result.setUint8(offset + 3, 255);
    }
  }
  return result;
}

void main() {
  test('trims pronounced symmetric letterbox bands', () {
    final result = portraitBlackBars(
      portrait(96, 200, top: 20, bottom: 24), 96, 200,
    );
    expect(result.top, 20);
    expect(result.bottom, 24);
  });

  test('does not trim a naturally dark portrait', () {
    final result = portraitBlackBars(
      portrait(96, 200, top: 20, bottom: 24, darkContent: true), 96, 200,
    );
    expect(result.top, 0);
    expect(result.bottom, 0);
  });

  test('preserves images with only one dark edge', () {
    final result = portraitBlackBars(
      portrait(96, 200, top: 24, bottom: 0), 96, 200,
    );
    expect(result.top, 0);
    expect(result.bottom, 0);
  });
}

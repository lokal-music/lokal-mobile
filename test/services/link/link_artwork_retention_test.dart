import 'dart:io';
import 'dart:typed_data';

import 'package:flick/services/album_art_service.dart';
import 'package:flick/services/link/lokal_desktop_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('desktop linked album markers resolve stable IDs across restarts', () {
    expect(
      AlbumArtService.markerForDesktopArtwork(
        'lokal://12/track-123',
        'lokal-cover://track-123',
      ),
      'track-123',
    );
    expect(
      AlbumArtService.markerForDesktopArtwork(
        'lokal://12/track-123',
        null,
      ),
      'track-123',
    );
    expect(
      AlbumArtService.markerForDesktopArtwork(
        'webdav://12/track-123',
        'lokal-cover://track-123',
      ),
      isNull,
    );
  });

  test('mobile history art is an actual small JPEG, not an audio or file URL', () {
    final picture = img.Image(width: 900, height: 600);
    final png = Uint8List.fromList(img.encodePng(picture));
    final encoded = linkHistoryCoverJpeg(png);
    expect(encoded, isNotNull);
    expect(encoded!.length, lessThanOrEqualTo(180000));
    expect(encoded.sublist(0, 3), [0xff, 0xd8, 0xff]);
    final decoded = img.decodeJpg(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(384));
    expect(decoded.height, lessThanOrEqualTo(384));
    expect(linkHistoryCoverJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('cover transfer cannot block automatic listening history or bulk sync', () {
    final coordinator =
        File('lib/services/link/link_sync_coordinator.dart').readAsStringSync();
    final source = File('lib/services/link/lokal_desktop_source.dart')
        .readAsStringSync();
    final journal = File('lib/services/link/link_journal.dart')
        .readAsStringSync();
    final artwork = File('lib/services/album_art_service.dart')
        .readAsStringSync();
    expect(coordinator, contains('unawaited(LokalDesktopSource.instance.uploadHistoryArtwork('));
    expect(coordinator, contains('unawaited(source.uploadRecentHistoryArtwork('));
    expect(source, contains("path: '/api/remote/history/artwork'"));
    expect(source, contains('const Duration(days: 30)'));
    expect(source, contains('maxCovers: maxCovers'));
    expect(journal, contains("'album_artist': song.albumArtist ?? ''"));
    expect(artwork, contains("uri.scheme != 'lokal'"));
    expect(artwork, contains("uri.host}/cover/"));
  });
}

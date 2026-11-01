import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/album_art_import_service.dart';

AlbumArtCandidate cover(String title, String artist, String image) =>
    AlbumArtCandidate(
      title: title,
      artist: artist,
      imageUrl: 'https://cdn.test/$image.jpg',
      previewUrl: 'https://cdn.test/$image.jpg',
      sourceLabel: 'iTunes',
    );

void main() {
  test('SZA album artwork ranks ahead of same-named unrelated releases', () {
    final results = relevantAlbumArtwork(
      album: 'SOS',
      artist: 'SZA',
      candidates: [
        cover('SOS', 'Other Artist', 'wrong'),
        cover('SOS (Deluxe)', 'SZA', 'deluxe'),
        cover('SOS', 'SZA', 'exact'),
      ],
    );
    expect(results.map((c) => c.imageUrl).toList(), [
      'https://cdn.test/exact.jpg',
      'https://cdn.test/deluxe.jpg',
    ]);
  });

  test('duplicate source URLs do not consume the candidate limit', () {
    final same = cover('Album', 'Artist', 'one');
    final results = relevantAlbumArtwork(
      album: 'Album', artist: 'Artist',
      candidates: [same, same, cover('Album', 'Artist', 'two')],
    );
    expect(results.length, 2);
  });

  test('similarly named releases by different artists are rejected', () {
    expect(relevantAlbumArtwork(
      album: 'Dangerous', artist: 'Artist A',
      candidates: [
        cover('Dangerous', 'Artist B', 'bad'),
        cover('Dangerously', 'Artist A', 'different-title'),
      ],
    ), isEmpty);
  });
}

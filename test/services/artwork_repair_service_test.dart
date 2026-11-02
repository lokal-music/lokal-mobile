import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_import_service.dart';
import 'package:flick/services/artwork_repair_service.dart';
import 'package:flutter_test/flutter_test.dart';

Song song({String album = 'Album One', String artist = 'Artist One'}) => Song(
  id: 'test',
  title: 'Track',
  artist: artist,
  album: album,
  albumArtist: artist,
  duration: Duration.zero,
  fileType: 'FLAC',
  filePath: '/tmp/test.flac',
);

AlbumArtCandidate candidate({
  required String title,
  required String artist,
  String source = 'iTunes',
  String image = 'https://example.org/cover.jpg',
}) => AlbumArtCandidate(
  previewUrl: image,
  imageUrl: image,
  title: title,
  artist: artist,
  sourceLabel: source,
);

void main() {
  test('repair accepts only exact album and album-artist matches', () {
    final original = song();
    final valid = candidate(title: 'Album One', artist: 'Artist One');
    expect(exactRepairCandidate(original, [
      candidate(title: 'Album One (Remastered)', artist: 'Artist One'),
      candidate(title: 'Album One', artist: 'Wrong Artist'),
      valid,
    ])?.imageUrl, valid.imageUrl);
    expect(exactRepairCandidate(original, [
      candidate(title: 'Album One', artist: 'Wrong Artist'),
    ]), isNull);
  });

  test('multiple exact releases from one catalogue are ambiguous', () {
    expect(exactRepairCandidate(song(), [
      candidate(title: 'Album One', artist: 'Artist One', image: 'https://example.org/a.jpg'),
      candidate(title: 'Album One', artist: 'Artist One', image: 'https://example.org/b.jpg'),
    ]), isNull);
  });

  test('SAF and MediaStore library tracks are eligible for cover repair', () {
    final local = song().copyWith(filePath: '/storage/emulated/0/Music/one.flac');
    final mediaStore = song().copyWith(
      filePath: 'content://media/external/audio/media/123',
    );
    final document = song().copyWith(
      filePath: 'content://com.android.externalstorage.documents/tree/Music',
    );
    final remote = song().copyWith(
      filePath: 'webdav://11/Music/one.flac',
      sourceType: 'webdav',
    );
    expect(isRepairableLocalSource(local), isTrue);
    expect(isRepairableLocalSource(mediaStore), isTrue);
    expect(isRepairableLocalSource(document), isTrue);
    expect(isRepairableLocalSource(remote), isFalse);
  });

  test('automatic artwork is not treated as a manual selection', () {
    final importer = AlbumArtImportService.instance;
    expect(
      importer.isCustomArtworkPath('/data/album_art_overrides/handpicked.cover'),
      isTrue,
    );
    expect(
      importer.isCustomArtworkPath('/support/album_art_repairs/upgraded.cover'),
      isFalse,
    );
  });

  test('missing or placeholder album identities are not eligible', () {
    expect(canRepairAlbum(song(album: 'Unknown Album')), isFalse);
    expect(canRepairAlbum(song(album: '')), isFalse);
    expect(canRepairAlbum(song(album: 'Album One')), isTrue);
  });

  test('only substantial measured pixel improvement qualifies', () {
    expect(isCoverUpgrade(currentShortSide: 120, newShortSide: 1200), isTrue);
    expect(isCoverUpgrade(currentShortSide: 0, newShortSide: 1000), isTrue);
    expect(isCoverUpgrade(currentShortSide: 120, newShortSide: 400), isFalse);
    expect(isCoverUpgrade(currentShortSide: 600, newShortSide: 640), isFalse);
    expect(isCoverUpgrade(currentShortSide: 900, newShortSide: 1200), isFalse);
  });
}

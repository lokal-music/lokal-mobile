import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/features/konnekted/library/lokal_albums_artists.dart';
import 'package:flick/models/song.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'artist row announces name and count once, with favorite action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      const song = Song(
        id: '1',
        title: 'Song',
        artist: 'Unique Artist',
        duration: Duration(minutes: 3),
        fileType: 'FLAC',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lokalArtistsProvider.overrideWithValue(
              const AsyncData([
                LokalArtist('Unique Artist', [song]),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
            home: const LokalArtistsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = tester.getSemantics(find.text('Unique Artist')).label;
      expect(RegExp('Unique Artist').allMatches(label).length, 1);
      expect(label, contains('1 song'));
      expect(
        tester
            .getSemantics(find.byTooltip('Add to favorites'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
    },
  );
}

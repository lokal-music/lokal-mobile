import 'dart:ui' as ui;

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/navigation/root_navigator.dart';
import 'package:flick/core/theme/lokal_interaction.dart';
import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/features/konnekted/konnekted_data.dart';
import 'package:flick/features/konnekted/konnekted_dock.dart';
import 'package:flick/features/konnekted/konnekted_shell.dart';
import 'package:flick/features/konnekted/library/lokal_detail_header.dart';
import 'package:flick/features/konnekted/library/lokal_detail_fixed_backdrop.dart';
import 'package:flick/features/konnekted/library/lokal_detail_scroll_chrome.dart';
import 'package:flick/features/konnekted/library/lokal_genres.dart';
import 'package:flick/features/konnekted/library/lokal_music_detail_page.dart';
import 'package:flick/features/konnekted/library/lokal_online_catalogue.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReducedMotion implements ui.AccessibilityFeatures {
  @override
  bool get disableAnimations => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double fontSize) => fontSize <= 1 ? fontSize : fontSize * 2;
  @override
  double get textScaleFactor => 1;
}

class _Player extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _PlayerService extends Fake implements PlayerService {
  @override
  final isPlayingNotifier = ValueNotifier(false);
  @override
  final isNetworkLoadingNotifier = ValueNotifier(false);
  @override
  final currentSongNotifier = ValueNotifier<Song?>(null);
  @override
  final onlinePreparationTitleNotifier = ValueNotifier<String?>(null);
  @override
  final bufferedPositionNotifier = ValueNotifier(Duration.zero);
  @override
  final durationNotifier = ValueNotifier(Duration.zero);
  @override
  final playbackDesyncedNotifier = ValueNotifier(false);
  @override
  final onlinePlaybackError = ValueNotifier<String?>(null);
}

const _song = Song(
  id: '1',
  title: 'Song',
  artist: 'Artist',
  album: 'Album',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
);
const _duplicate = Song(
  id: '2',
  title: 'Song',
  artist: 'Artist',
  album: 'Album',
  year: 1999,
  duration: Duration(minutes: 7),
  fileType: 'FLAC',
);

Widget _app(Widget child) => ProviderScope(
  overrides: [
    konnektedLibraryProvider.overrideWithValue(const AsyncData([])),
    playerProvider.overrideWith(_Player.new),
    playerServiceProvider.overrideWithValue(_PlayerService()),
  ],
  child: MaterialApp(
    theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
    home: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConstants.setAnimationsEnabled(true);
  });
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  test('album duration requires every displayed row to be owned', () {
    expect(lokalAlbumRunningTime([]), isNull);
    expect(lokalAlbumRunningTime([_song, null]), isNull);
    expect(lokalAlbumRunningTime([_song, _duplicate]), '10 min');
  });

  testWidgets(
    'platform reduced motion and preference select clamping physics',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      const behavior = LokalScrollBehavior();
      expect(behavior.getScrollPhysics(context), isA<BouncingScrollPhysics>());
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          _ReducedMotion();
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      AppConstants.setAnimationsEnabled(false);
      expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('genre cards grow at double text scale', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: _NonlinearScaler(),
          ),
          child: const Scaffold(
            body: CustomScrollView(
              slivers: [
                LokalGenreGrid(
                  genres: [
                    LokalGenre('Long genre name for accessibility', [_song]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.mainAxisExtent, greaterThan(250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('album year fallback and row-owned duration', (tester) async {
    const release = LokalCatalogueAlbum(
      title: 'Album',
      artist: 'Artist',
      date: '2020-01-01',
    );
    Future<String?> metadata(List<Song> songs) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            konnektedLibraryProvider.overrideWithValue(AsyncData(songs)),
          ],
          child: MaterialApp(
            theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
            home: LokalMusicDetailPage.album(
              title: 'Album',
              artist: 'Artist',
              localSongs: songs,
              release: release,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .widget<LokalDetailHeader>(find.byType(LokalDetailHeader))
          .metadata;
    }

    expect(await metadata([]), '2020  ·  0 songs');
    expect(await metadata([_song]), '2020  ·  1 song  ·  3 min');
    expect(await metadata([_song, _duplicate]), '1999  ·  1 song  ·  3 min');
  });

  testWidgets('artist content keeps the theme background when scrolled',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final songs = List.generate(
      12,
      (index) => Song(
        id: '$index',
        title: 'Song $index',
        artist: 'Artist',
        album: 'Album $index',
        duration: const Duration(minutes: 3),
        fileType: 'FLAC',
      ),
    );
    await tester.pumpWidget(_app(LokalMusicDetailPage.artist(
      name: 'Artist',
      localSongs: songs,
    )));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, LokalTokens.resolve(LokalThemeId.dark).bg);
    // Artwork is fixed behind the scroll view; song/release slivers remain
    // opaque so the image doesn't bleed through rows during scrolling.
    expect(scaffold.body, isA<Stack>());
    expect(find.byType(LokalDetailFixedBackdrop), findsOneWidget);
    expect(find.byType(LokalDetailHeroWash), findsOneWidget);
    expect(find.byType(LokalDetailProgressiveTopBlur), findsOneWidget);
    expect(find.byType(LokalDetailFloatingControls), findsOneWidget);
    expect(
      tester.widget<LokalDetailHeader>(find.byType(LokalDetailHeader))
          .controlsInOverlay,
      isTrue,
    );
    expect(
      find.byType(DecoratedSliver),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system back at tab root keeps nested route and returns home once',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(KonnektedShell(runtimeBuilder: (child) => child)),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Library'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<KonnektedDock>(find.byType(KonnektedDock)).selected,
        KonnektedTab.library,
      );
      final navigator = nestedNavigatorKey.currentState!;
      expect(navigator.canPop(), isFalse);
      // A stale nested pop callback must not consume the root back action.
      tester
          .widget<NavigatorPopHandler<void>>(
            find.byType(NavigatorPopHandler<void>),
          )
          .onPopWithResult!(null);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(nestedNavigatorKey.currentState, same(navigator));
      expect(navigator.canPop(), isFalse);
      expect(
        tester.widget<KonnektedDock>(find.byType(KonnektedDock)).selected,
        KonnektedTab.listen,
      );
      expect(find.text('Press back again to exit'), findsNothing);
    },
  );

  testWidgets('system back pops a child without changing tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(KonnektedShell(runtimeBuilder: (child) => child)),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump(const Duration(milliseconds: 500));
    nestedNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Child route')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Child route'), findsNothing);
    expect(nestedNavigatorKey.currentState!.canPop(), isFalse);
    expect(
      tester.widget<KonnektedDock>(find.byType(KonnektedDock)).selected,
      KonnektedTab.library,
    );
  });
}

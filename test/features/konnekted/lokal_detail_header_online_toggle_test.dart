import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/features/konnekted/library/lokal_detail_header.dart';

void main() {
  testWidgets('album/artist online catalogue control is icon-only', (tester) async {
    var toggles = 0;
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);

    Widget header({required bool active, bool artist = false}) => MaterialApp(
      theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
      home: Scaffold(
        body: LokalDetailHeader(
          title: artist ? 'An Artist' : 'An Album',
          artwork: const ColoredBox(color: Colors.blueGrey),
          isArtist: artist,
          background: Colors.black,
          onBack: () {},
          onOnline: () => toggles++,
          onlineEnabled: active,
          onMore: () {},
        ),
      ),
    );

    await tester.pumpWidget(header(active: false));
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
    expect(find.byIcon(Icons.language_outlined), findsOneWidget);
    final offlineLabel = find.bySemanticsLabel('Enable online catalogue');
    expect(offlineLabel, findsOneWidget);
    expect(tester.getSemantics(offlineLabel).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(find.text('Online catalogue'), findsNothing);
    await tester.tap(find.byIcon(Icons.language_outlined));
    expect(toggles, 1);

    await tester.pumpWidget(header(active: true, artist: true));
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    final onlineLabel = find.bySemanticsLabel('Disable online catalogue');
    expect(onlineLabel, findsOneWidget);
    expect(tester.getSemantics(onlineLabel).hasFlag(SemanticsFlag.isButton), isTrue);
    expect(find.text('Online catalogue'), findsNothing);
    await tester.tap(find.byIcon(Icons.language_rounded));
    expect(toggles, 2);
  });

  testWidgets('light album header retains contrast and respects busy state',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.light)),
      home: Scaffold(
        body: LokalDetailHeader(
          title: 'Album',
          artwork: const SizedBox.expand(),
          isArtist: false,
          background: Colors.white,
          onBack: () {},
          onOnline: () => taps++,
          onlineEnabled: true,
          onlineDisabled: true,
          onMore: () {},
        ),
      ),
    ));
    final enabledIcon = tester.widget<Icon>(find.byIcon(Icons.language_rounded));
    expect(enabledIcon.color, LokalTokens.resolve(LokalThemeId.light).text);
    await tester.tap(find.byIcon(Icons.language_rounded));
    expect(taps, 0, reason: 'A download must not allow changing catalogue mode');
    expect(find.text('Online catalogue'), findsNothing);
  });

  testWidgets('catalogue icon shows loading state without additional text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
      home: Scaffold(
        body: LokalDetailHeader(
          title: 'Album',
          artwork: const SizedBox.expand(),
          isArtist: false,
          background: Colors.black,
          onBack: () {},
          onOnline: () {},
          onlineEnabled: true,
          onlineLoading: true,
          onMore: () {},
        ),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Online catalogue'), findsNothing);
  });
}

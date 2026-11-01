import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/features/konnekted/library/lokal_detail_header.dart';

void main() {
  testWidgets('album/artist online catalogue control is icon-only', (tester) async {
    var toggles = 0;

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
    expect(find.text('Online catalogue'), findsNothing);
    await tester.tap(find.byIcon(Icons.language_outlined));
    expect(toggles, 1);

    await tester.pumpWidget(header(active: true, artist: true));
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(find.text('Online catalogue'), findsNothing);
    await tester.tap(find.byIcon(Icons.language_rounded));
    expect(toggles, 2);
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

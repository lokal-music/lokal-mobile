import 'package:flick/core/theme/lokal_theme.dart';
import 'package:flick/core/theme/lokal_tokens.dart';
import 'package:flick/features/konnekted/library/lokal_detail_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('artist portrait fills the top inset and opens its viewer on tap',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var artworkTaps = 0;
    var moreTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 35),
          ),
          child: Scaffold(
            body: LokalDetailHeader(
              title: 'Artist with a portrait',
              artwork: const ColoredBox(
                key: ValueKey('portrait'),
                color: Colors.deepPurple,
                child: SizedBox.expand(),
              ),
              isArtist: true,
              background: Colors.black,
              onArtworkTap: () => artworkTaps++,
              onBack: () {},
              onMore: () => moreTaps++,
              onOnline: () {},
              onlineEnabled: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The photograph covers the entire hero, including the simulated Android
    // status-bar inset; the action buttons are separately inset by SafeArea.
    expect(tester.getTopLeft(find.byKey(const ValueKey('portrait'))).dy, 0);
    await tester.tapAt(const Offset(190, 210));
    await tester.pump();
    expect(artworkTaps, 1);
    expect(moreTaps, 0);

    // The overlay must not block header controls either.
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pump();
    expect(moreTaps, 1);
    expect(artworkTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album cover tap is preserved by the shared detail header',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: LokalTheme.build(LokalTokens.resolve(LokalThemeId.dark)),
        home: Scaffold(
          body: LokalDetailHeader(
            title: 'Album',
            artwork: const ColoredBox(color: Colors.red),
            isArtist: false,
            background: Colors.black,
            onArtworkTap: () => taps++,
            onBack: () {},
            onMore: () {},
            onOnline: () {},
            onlineEnabled: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(195, 230));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

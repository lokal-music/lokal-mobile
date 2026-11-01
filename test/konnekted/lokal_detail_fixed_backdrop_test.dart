import 'package:flick/features/konnekted/library/lokal_detail_fixed_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixed hero uses blur and alpha fade without a dark scrim',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 440,
            width: 390,
            child: LokalDetailFixedBackdrop(
              artwork: ColoredBox(
                key: ValueKey('fixed-artwork'),
                color: Colors.cyan,
              ),
              background: Colors.white,
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('fixed-artwork'))),
        const Size(390, 440));
    final masks = tester.widgetList<ShaderMask>(
      find.descendant(
        of: find.byType(LokalDetailFixedBackdrop),
        matching: find.byType(ShaderMask),
      ),
    );
    expect(masks.length, 1);
    expect(masks.single.blendMode, BlendMode.dstIn);
    expect(
      find.descendant(
        of: find.byType(LokalDetailFixedBackdrop),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    // There should be no darkening/shadow/tint overlay over the artwork.
    expect(
      find.descendant(
        of: find.byType(LokalDetailFixedBackdrop),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/navigation/lokal_navigation_switcher.dart';

void main() {
  setUp(() => AppConstants.setAnimationsEnabled(true));
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  testWidgets('tab change keeps old content visible until next is painted',
      (tester) async {
    Widget page(String tab) => MaterialApp(
      home: LokalNavigationSwitcher(
        child: ColoredBox(
          key: ValueKey(tab),
          color: tab == 'old' ? const Color(0xFF224466) : const Color(0xFF446622),
          child: Text(tab, textDirection: TextDirection.ltr),
        ),
      ),
    );

    await tester.pumpWidget(page('old'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(page('new'));
    await tester.pump(const Duration(milliseconds: 50));

    // Do not flash the navigator's empty backdrop during transition.
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LokalNavigationSwitcher),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(find.text('new'), findsOneWidget);
    expect(find.text('old'), findsNothing,
        reason: 'Old tabs are transient, not persistently cached');
  });

  testWidgets('reduced motion removes transient tab immediately',
      (tester) async {
    AppConstants.setAnimationsEnabled(false);
    Widget page(String label) => MaterialApp(
      home: LokalNavigationSwitcher(
        child: Text(label, key: ValueKey(label), textDirection: TextDirection.ltr),
      ),
    );
    await tester.pumpWidget(page('first'));
    await tester.pumpWidget(page('second'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}

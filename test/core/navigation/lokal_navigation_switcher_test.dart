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

  for (final motion in [1, -1]) {
    testWidgets('Home tab moves in the correct direction: $motion', (tester) async {
      Widget page(String tab) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: LokalNavigationSwitcher(
            direction: motion,
            child: SizedBox.expand(
              key: ValueKey(tab),
              child: Center(child: Text(tab)),
            ),
          ),
        ),
      );

      await tester.pumpWidget(page('Library'));
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.text('Library')).dx;
      await tester.pumpWidget(page('Home'));
      await tester.pump(const Duration(milliseconds: 45));
      expect(
        (tester.getCenter(find.text('Home')).dx - center) * motion,
        greaterThan(0),
        reason: 'Incoming Home must enter from the selected tab direction',
      );
      expect(
        (tester.getCenter(find.text('Library')).dx - center) * motion,
        lessThan(0),
        reason: 'Departing page must recede instead of ghosting over Home',
      );
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });
  }

  for (final textDirection in TextDirection.values) {
    for (final tabDirection in [-1, 1]) {
      testWidgets(
        'tab pages meet without overlap or black gap: '
        '$textDirection / $tabDirection',
        (tester) async {
          Widget page(String name) => MaterialApp(
            home: Directionality(
              textDirection: textDirection,
              child: LokalNavigationSwitcher(
                direction: tabDirection,
                child: SizedBox.expand(
                  key: ValueKey(name),
                  child: ColoredBox(
                    color: name == 'old'
                        ? const Color(0xFF28405C)
                        : const Color(0xFF54652A),
                    child: Center(child: Text(name)),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpWidget(page('old'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(page('new'));
          final sign = (textDirection == TextDirection.rtl ? -1 : 1) *
              tabDirection;

          // At every sampled progress both pages are adjacent. Their
          // translated bounds exactly partition the viewport: no double
          // exposure and no unpainted strip between them.
          for (final milliseconds in [15, 35, 50, 65, 80]) {
            await tester.pump(Duration(milliseconds: milliseconds));
            final oldRect = tester.getRect(find.byKey(const ValueKey('old')));
            final newRect = tester.getRect(find.byKey(const ValueKey('new')));
            final screen = tester.getSize(find.byType(LokalNavigationSwitcher));
            if (sign > 0) {
              expect((oldRect.right - newRect.left).abs(), lessThan(.1));
              expect(oldRect.left, lessThanOrEqualTo(0));
              expect(newRect.right, greaterThanOrEqualTo(screen.width));
            } else {
              expect((newRect.right - oldRect.left).abs(), lessThan(.1));
              expect(newRect.left, lessThanOrEqualTo(0));
              expect(oldRect.right, greaterThanOrEqualTo(screen.width));
            }
          }

          expect(
            find.descendant(
              of: find.byType(LokalNavigationSwitcher),
              matching: find.byType(FadeTransition),
            ),
            findsNothing,
          );
          await tester.pumpAndSettle();
          expect(find.text('old'), findsNothing);
          expect(find.text('new'), findsOneWidget);
        },
      );
    }
  }

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

  testWidgets('rapid switches mount only the current and latest outgoing tab', (
    tester,
  ) async {
    Widget page(String tab) => MaterialApp(
      home: LokalNavigationSwitcher(child: Text(tab, key: ValueKey(tab))),
    );

    await tester.pumpWidget(page('first'));
    await tester.pumpWidget(page('second'));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(page('third'));
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
    expect(find.text('third'), findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    testWidgets('tab motion follows $direction', (tester) async {
      Widget page(String tab) => MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: LokalNavigationSwitcher(
            child: SizedBox.expand(
              key: ValueKey(tab),
              child: Center(child: Text(tab)),
            ),
          ),
        ),
      );

      await tester.pumpWidget(page('old'));
      final center = tester.getCenter(find.text('old')).dx;
      await tester.pumpWidget(page('new'));
      await tester.pump(const Duration(milliseconds: 50));
      final sign = direction == TextDirection.ltr ? 1 : -1;
      expect(
        (tester.getCenter(find.text('new')).dx - center) * sign,
        greaterThan(0),
      );
      expect(
        (tester.getCenter(find.text('old')).dx - center) * sign,
        lessThan(0),
      );
      await tester.pumpAndSettle();
    });
  }
}

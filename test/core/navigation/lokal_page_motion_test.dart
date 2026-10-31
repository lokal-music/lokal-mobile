import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/navigation/lokal_page_motion.dart';

void main() {
  setUp(() => AppConstants.setAnimationsEnabled(true));
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  testWidgets('push and pop animate both foreground and previous page',
      (tester) async {
    final primary = AnimationController(vsync: tester, value: 0);
    final secondary = AnimationController(vsync: tester, value: 0);
    addTearDown(primary.dispose);
    addTearDown(secondary.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => const LokalPageMotion().buildTransitions<void>(
          MaterialPageRoute<void>(builder: (_) => const SizedBox()),
          context,
          primary,
          secondary,
          const SizedBox(key: Key('detail')),
        ),
      ),
    ));

    List<double> offsets() => tester
        .widgetList<SlideTransition>(find.byType(SlideTransition))
        .map((transition) => transition.position.value.dx)
        .toList();

    expect(offsets(), contains(closeTo(.22, .001)));

    primary.value = .5;
    secondary.value = .5;
    await tester.pump();
    final middle = offsets();
    expect(middle.any((value) => value > .01), isTrue,
        reason: 'incoming route should move in from the right');
    expect(middle.any((value) => value < -.01), isTrue,
        reason: 'previous route should recede toward the left');

    primary.value = 1;
    secondary.value = 1;
    await tester.pump();
    expect(offsets(), contains(closeTo(-.14, .001)));

    primary.value = 0;
    secondary.value = 0;
    await tester.pump();
    expect(offsets(), contains(closeTo(.22, .001)),
        reason: 'Back must return the foreground along the reverse path');
  });

  testWidgets('respects system reduced motion', (tester) async {
    final primary = AnimationController(vsync: tester, value: .4);
    final secondary = AnimationController(vsync: tester, value: .6);
    addTearDown(primary.dispose);
    addTearDown(secondary.dispose);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) => const LokalPageMotion().buildTransitions<void>(
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
            context,
            primary,
            secondary,
            const Text('Static detail'),
          ),
        ),
      ),
    ));
    expect(find.text('Static detail'), findsOneWidget);
    expect(find.byType(SlideTransition), findsNothing);
  });
}

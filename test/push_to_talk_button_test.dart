import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilo_translate/features/translator/presentation/push_to_talk_button.dart';

Widget _host({
  required bool enabled,
  Duration minHold = const Duration(milliseconds: 250),
  required void Function() onStart,
  required void Function() onStop,
  required void Function() onShort,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: PushToTalkButton(
            title: 'English',
            subtitle: 'Press and hold to speak',
            color: Colors.blue,
            enabled: enabled,
            minHold: minHold,
            onStart: onStart,
            onStop: onStop,
            onShortPress: onShort,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('press down calls onStart', (tester) async {
    var started = false;
    await tester.pumpWidget(_host(
      enabled: true,
      onStart: () => started = true,
      onStop: () {},
      onShort: () {},
    ));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PushToTalkButton)));
    await tester.pump();
    expect(started, isTrue);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('quick press triggers onShortPress, not onStop', (tester) async {
    var stopped = false;
    var short = false;
    await tester.pumpWidget(_host(
      enabled: true,
      onStart: () {},
      onStop: () => stopped = true,
      onShort: () => short = true,
    ));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PushToTalkButton)));
    await tester.pump();
    await gesture.up(); // released almost immediately
    await tester.pump();

    expect(short, isTrue);
    expect(stopped, isFalse);
  });

  testWidgets('long enough hold triggers onStop', (tester) async {
    var stopped = false;
    var short = false;
    await tester.pumpWidget(_host(
      enabled: true,
      minHold: const Duration(milliseconds: 1),
      onStart: () {},
      onStop: () => stopped = true,
      onShort: () => short = true,
    ));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PushToTalkButton)));
    await tester.pump();
    // Let real wall-clock time advance beyond minHold.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await gesture.up();
    await tester.pump();

    expect(stopped, isTrue);
    expect(short, isFalse);
  });

  testWidgets('disabled button ignores presses', (tester) async {
    var started = false;
    await tester.pumpWidget(_host(
      enabled: false,
      onStart: () => started = true,
      onStop: () {},
      onShort: () {},
    ));

    final gesture = await tester.startGesture(tester.getCenter(find.byType(PushToTalkButton)));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(started, isFalse);
  });
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

class GroupTest extends StatefulWidget {
  const GroupTest({super.key});

  @override
  GroupTestState createState() => GroupTestState();
}

class GroupTestState extends State<GroupTest> {
  var group = AutoSizeGroup();
  var width1 = 300.0;
  var width2 = 300.0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: <Widget>[
          SizedBox(
            width: width1,
            height: 100,
            child: AutoSizeText(
              'XXXXXX',
              style: TextStyle(fontSize: 60),
              minFontSize: 1,
              maxLines: 1,
              group: group,
            ),
          ),
          SizedBox(
            width: width2,
            height: 100.0,
            child: AutoSizeText(
              'XXXXXX',
              style: TextStyle(fontSize: 60),
              minFontSize: 1,
              maxLines: 1,
              group: group,
            ),
          ),
        ],
      ),
    );
  }

  void refresh() {
    setState(() {});
  }
}

void _expectFontSizes(WidgetTester tester, double fontSize) {
  final texts = tester.widgetList(find.byType(Text));
  for (final text in texts) {
    expect(effectiveFontSize(text as Text), fontSize);
  }
}

void main() {
  group('AutoSizeGroup', () {
    testWidgets('should synchronize font sizes after state updates', (
      tester,
    ) async {
      await tester.pumpWidget(const GroupTest());

      _expectFontSizes(tester, 50);

      final state = tester.state(find.byType(GroupTest)) as GroupTestState;

      state.width1 = 200;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 33);

      state.width2 = 150;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 25);

      state.width2 = 100;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 16);

      state.width1 = 60;
      state.width2 = 60;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 10);

      state.width1 = 200;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 10);

      state.width2 = 250;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 33);

      state.width1 = 250;
      state.refresh();
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 41);

      state.width1 = 300;
      state.width2 = 300;
      state.refresh();
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      _expectFontSizes(tester, 50);

      await tester.pump(Duration.zero);
    });

    testWidgets(
      'should transfer and detach a stable member without stale contributions',
      (tester) async {
        final firstGroup = AutoSizeGroup();
        final secondGroup = AutoSizeGroup();
        const movingWidgetKey = ValueKey<String>('moving-widget');
        const movingTextKey = ValueKey<String>('moving-text');
        const firstSurvivorKey = ValueKey<String>('first-survivor');
        const secondSurvivorKey = ValueKey<String>('second-survivor');
        AutoSizeGroup? membership = firstGroup;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: <Widget>[
                    AutoSizeText(
                      '',
                      key: movingWidgetKey,
                      textKey: movingTextKey,
                      style: const TextStyle(fontSize: 20),
                      presetFontSizes: const <double>[20],
                      textScaler: TextScaler.noScaling,
                      group: membership,
                    ),
                    AutoSizeText(
                      '',
                      textKey: firstSurvivorKey,
                      style: const TextStyle(fontSize: 40),
                      presetFontSizes: const <double>[40, 20],
                      textScaler: TextScaler.noScaling,
                      group: firstGroup,
                    ),
                    AutoSizeText(
                      '',
                      textKey: secondSurvivorKey,
                      style: const TextStyle(fontSize: 50),
                      presetFontSizes: const <double>[50, 20],
                      textScaler: TextScaler.noScaling,
                      group: secondGroup,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(effectiveFontSize(tester.widget(find.byKey(movingTextKey))), 20);
        expect(
          effectiveFontSize(tester.widget(find.byKey(firstSurvivorKey))),
          20,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(secondSurvivorKey))),
          50,
        );

        update(() => membership = secondGroup);
        await tester.pump();
        await tester.pump();
        expect(effectiveFontSize(tester.widget(find.byKey(movingTextKey))), 20);
        expect(
          effectiveFontSize(tester.widget(find.byKey(firstSurvivorKey))),
          40,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(secondSurvivorKey))),
          20,
        );

        update(() => membership = null);
        await tester.pump();
        await tester.pump();
        expect(effectiveFontSize(tester.widget(find.byKey(movingTextKey))), 20);
        expect(
          effectiveFontSize(tester.widget(find.byKey(firstSurvivorKey))),
          40,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(secondSurvivorKey))),
          50,
        );
      },
    );

    testWidgets(
      'should retain one membership when its domain and scaler change',
      (tester) async {
        final group = AutoSizeGroup();
        const changingWidgetKey = ValueKey<String>('changing-widget');
        const changingTextKey = ValueKey<String>('changing-text');
        const survivorTextKey = ValueKey<String>('domain-survivor');
        var presets = <double>[20];
        TextScaler scaler = TextScaler.noScaling;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: <Widget>[
                    AutoSizeText(
                      '',
                      key: changingWidgetKey,
                      textKey: changingTextKey,
                      style: const TextStyle(fontSize: 20),
                      presetFontSizes: presets,
                      textScaler: scaler,
                      group: group,
                    ),
                    AutoSizeText(
                      '',
                      textKey: survivorTextKey,
                      style: const TextStyle(fontSize: 40),
                      presetFontSizes: const <double>[40, 20],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(changingTextKey))),
          20,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          20,
        );

        update(() {
          presets = <double>[15];
          scaler = const TextScaler.linear(2);
        });
        await tester.pump();
        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(changingTextKey))),
          30,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          20,
        );

        update(() => presets = <double>[25]);
        await tester.pump();
        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(changingTextKey))),
          50,
        );
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          40,
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      'should raise the limit once and ignore a member disposed before notify',
      (tester) async {
        final group = AutoSizeGroup();
        const minimumWidgetKey = ValueKey<String>('minimum-widget');
        const minimumTextKey = ValueKey<String>('minimum-text');
        const survivorWidgetKey = ValueKey<String>('survivor-widget');
        const survivorTextKey = ValueKey<String>('survivor-text');
        var showMinimum = true;
        late StateSetter update;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: <Widget>[
                    if (showMinimum)
                      AutoSizeText(
                        '',
                        key: minimumWidgetKey,
                        textKey: minimumTextKey,
                        style: const TextStyle(fontSize: 20),
                        presetFontSizes: const <double>[20],
                        textScaler: TextScaler.noScaling,
                        group: group,
                      ),
                    AutoSizeText(
                      '',
                      key: survivorWidgetKey,
                      textKey: survivorTextKey,
                      style: const TextStyle(fontSize: 40),
                      presetFontSizes: const <double>[40, 20],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          20,
        );

        update(() => showMinimum = false);
        await tester.pump();
        expect(find.byKey(minimumTextKey), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          40,
        );
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(
          effectiveFontSize(tester.widget(find.byKey(survivorTextKey))),
          40,
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

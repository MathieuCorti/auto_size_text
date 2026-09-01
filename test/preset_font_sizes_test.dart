import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

Future<void> _expectArgumentError(
  WidgetTester tester,
  List<double> presetFontSizes,
) async {
  await pump(
    tester: tester,
    widget: AutoSizeText(
      'AutoSizeText Test',
      key: UniqueKey(),
      presetFontSizes: presetFontSizes,
    ),
  );
  expect(tester.takeException(), isA<ArgumentError>());
}

void main() {
  group('AutoSizeText', () {
    testWidgets('should select from preset font sizes', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 100,
        widget: SizedBox(
          width: 500,
          height: 100,
          child: AutoSizeText('XXXXX', presetFontSizes: [100, 50, 5]),
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 50,
        widget: SizedBox(
          width: 300,
          height: 100,
          child: AutoSizeText('XXXXX', presetFontSizes: [100, 50, 5]),
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 5,
        widget: SizedBox(
          width: 20,
          height: 100,
          child: AutoSizeText('XXXXX', presetFontSizes: [100, 50, 5]),
        ),
      );
    });

    testWidgets(
      'should deduplicate descending presets including zero without mutation',
      (tester) async {
        final presets = <double>[40, 40, 20, 20, 0];
        final original = List<double>.of(presets);

        await pumpAndExpectFontSize(
          tester: tester,
          expectedFontSize: 40,
          widget: AutoSizeText('', presetFontSizes: presets),
        );
        expect(presets, orderedEquals(original));

        await pumpAndExpectFontSize(
          tester: tester,
          expectedFontSize: 0,
          widget: SizedBox(
            width: 0,
            height: 0,
            child: AutoSizeText('XXXXX', maxLines: 1, presetFontSizes: presets),
          ),
        );
        expect(presets, orderedEquals(original));
      },
    );

    testWidgets('should accept an immutable descending preset list', (
      tester,
    ) async {
      final presets = List<double>.unmodifiable(<double>[40, 20, 0]);

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 40,
        widget: AutoSizeText('', presetFontSizes: presets),
      );
      expect(presets, orderedEquals(<double>[40, 20, 0]));
    });

    testWidgets(
      'should ignore regular grid parameters for both preset constructors',
      (tester) async {
        final widgets = <AutoSizeText>[
          const AutoSizeText(
            '',
            minFontSize: -1,
            maxFontSize: 0,
            stepGranularity: 0,
            presetFontSizes: <double>[20, 10],
          ),
          const AutoSizeText.rich(
            TextSpan(text: ''),
            minFontSize: -1,
            maxFontSize: 0,
            stepGranularity: 0,
            presetFontSizes: <double>[20, 10],
          ),
        ];

        for (final widget in widgets) {
          await pump(tester: tester, widget: widget);
          expect(tester.takeException(), isNull);
          expect(find.byType(Text), findsOneWidget);
        }
      },
    );

    testWidgets('should select the largest preset that actually fits', (
      tester,
    ) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: const SizedBox(
          height: 30,
          child: AutoSizeText(
            'XXXXX',
            maxLines: 1,
            overflowReplacement: SizedBox(key: ValueKey('overflow')),
            presetFontSizes: <double>[40, 30, 20, 10],
            textDirection: TextDirection.ltr,
          ),
        ),
      );
      expect(effectiveFontSize(text), 30);
      expect(doesTextFit(text, double.infinity, 30), isTrue);
    });

    testWidgets('should keep the larger exact preset of a near-equal pair', (
      tester,
    ) async {
      const presets = <double>[40, 39.99999999999999, 20];

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 40,
        widget: const AutoSizeText('', presetFontSizes: presets),
      );
    });

    testWidgets(
      'should reject exact preset increases before near-equal deduplication',
      (tester) async {
        for (final presets in <List<double>>[
          <double>[20, 20.000000000000004, 10],
          <double>[20, 19.999999999999996, 20, 10],
        ]) {
          await _expectArgumentError(tester, presets);
        }
      },
    );

    testWidgets('should reject invalid preset lists at runtime', (
      tester,
    ) async {
      for (final presets in <List<double>>[
        <double>[],
        <double>[10, 20],
        <double>[40, 20, 30],
        <double>[40, -1],
        <double>[40, double.nan],
        <double>[40, double.infinity],
        <double>[40, double.negativeInfinity],
      ]) {
        await _expectArgumentError(tester, presets);
      }
    });
  });
}

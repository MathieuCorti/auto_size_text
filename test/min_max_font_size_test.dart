import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

Future<void> _expectArgumentError(
  WidgetTester tester,
  AutoSizeText widget,
) async {
  await pump(tester: tester, widget: widget);
  expect(tester.takeException(), isA<ArgumentError>());
}

void main() {
  group('AutoSizeText', () {
    testWidgets('should reject a non-finite or negative minimum at runtime', (
      tester,
    ) async {
      for (final value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
      ]) {
        await _expectArgumentError(
          tester,
          AutoSizeText(
            'AutoSizeText Test',
            key: UniqueKey(),
            style: const TextStyle(fontSize: 25),
            minFontSize: value,
          ),
        );
      }
    });

    testWidgets('should reject an invalid maximum at runtime', (tester) async {
      for (final value in <double>[
        double.nan,
        double.negativeInfinity,
        -1,
        0,
      ]) {
        await _expectArgumentError(
          tester,
          AutoSizeText(
            'AutoSizeText Test',
            key: UniqueKey(),
            style: const TextStyle(fontSize: 25),
            maxFontSize: value,
          ),
        );
      }

      await _expectArgumentError(
        tester,
        AutoSizeText(
          'AutoSizeText Test',
          key: UniqueKey(),
          style: const TextStyle(fontSize: 25),
          minFontSize: 20,
          maxFontSize: 10,
        ),
      );
    });

    testWidgets('should reject an invalid step at runtime', (tester) async {
      for (final value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
        0,
        0.09,
      ]) {
        await _expectArgumentError(
          tester,
          AutoSizeText(
            'AutoSizeText Test',
            key: UniqueKey(),
            style: const TextStyle(fontSize: 25),
            stepGranularity: value,
          ),
        );
      }
    });

    testWidgets('should reject an invalid reference font size at runtime', (
      tester,
    ) async {
      for (final value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
      ]) {
        await _expectArgumentError(
          tester,
          AutoSizeText(
            'AutoSizeText Test',
            key: UniqueKey(),
            style: TextStyle(fontSize: value),
          ),
        );
      }
    });

    testWidgets('should reject an invalid text scale factor at runtime', (
      tester,
    ) async {
      for (final value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
      ]) {
        await _expectArgumentError(
          tester,
          AutoSizeText(
            'AutoSizeText Test',
            key: UniqueKey(),
            style: const TextStyle(fontSize: 25),
            textScaleFactor: value,
          ),
        );
      }
    });

    testWidgets('should accept zero lower inputs and an infinite maximum', (
      tester,
    ) async {
      final negativeZeroText = await pumpAndGetText(
        tester: tester,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 1),
            minFontSize: -0.0,
            maxFontSize: double.infinity,
            maxLines: 1,
          ),
        ),
      );
      final negativeZeroResult = effectiveFontSize(negativeZeroText);
      expect(negativeZeroResult, 0);
      expect(negativeZeroResult.isNegative, isFalse);

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 0,
        widget: const AutoSizeText(
          '',
          style: TextStyle(fontSize: -0.0),
          minFontSize: 0,
          maxFontSize: double.infinity,
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 0,
        widget: const AutoSizeText(
          'scaled to zero',
          style: TextStyle(fontSize: 20),
          textScaleFactor: 0,
        ),
      );
    });

    testWidgets('should respect minFontSize', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 15,
        widget: SizedBox(
          width: 10,
          height: 10,
          child: AutoSizeText(
            'AutoSizeText Test',
            style: TextStyle(fontSize: 25),
            minFontSize: 15,
          ),
        ),
      );
    });

    testWidgets('should exceed minFontSize when enough space is available', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 30,
        widget: SizedBox(
          width: 120,
          height: 40,
          child: AutoSizeText(
            'XXXX',
            style: TextStyle(fontSize: 30, fontFamily: 'Roboto'),
            minFontSize: 15,
          ),
        ),
      );
    });

    testWidgets('should respect maxFontSize', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 20,
        widget: DefaultTextStyle(
          style: TextStyle(fontSize: 30),
          child: AutoSizeText('AutoSizeText Test', maxFontSize: 20),
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 20,
        widget: AutoSizeText(
          'AutoSizeText Test',
          style: TextStyle(fontSize: 30),
          maxFontSize: 20,
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 20,
        widget: AutoSizeText(
          'AutoSizeText Test',
          style: TextStyle(fontSize: 20),
          maxFontSize: 30,
        ),
      );
    });
  });
}

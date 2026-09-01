import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

class _CountingTextSpan extends TextSpan {
  const _CountingTextSpan(this.onBuild)
    : super(text: 'X', style: const TextStyle(fontSize: 1));

  final VoidCallback onBuild;

  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    onBuild();
    super.build(builder, textScaler: textScaler, dimensions: dimensions);
  }
}

double _textWidthAt(double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'XXXXX',
      style: TextStyle(fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  try {
    painter.layout();
    return painter.width;
  } finally {
    painter.dispose();
  }
}

Future<void> _expectArgumentError(
  WidgetTester tester,
  AutoSizeText widget,
) async {
  await pump(tester: tester, widget: widget);
  expect(tester.takeException(), isA<ArgumentError>());
}

void main() {
  group('AutoSizeText candidate grid', () {
    testWidgets('should accept the decimal grid 0.3/0.1', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 0.3,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 0.5),
            minFontSize: 0.3,
            stepGranularity: 0.1,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets('should anchor the 16.3/1 grid at its exact minimum', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 16.3,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 20.3),
            minFontSize: 16.3,
            stepGranularity: 1,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets('should never select 10 for a 12/5 grid', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 12,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 23),
            minFontSize: 12,
            stepGranularity: 5,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets('should retain both bounds when the interval is below a step', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 13,
        widget: const AutoSizeText(
          '',
          style: TextStyle(fontSize: 13),
          minFontSize: 12,
          stepGranularity: 5,
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 12,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 13),
            minFontSize: 12,
            stepGranularity: 5,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets('should select an anchored candidate in a non-multiple range', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 22,
        widget: SizedBox(
          width: _textWidthAt(22),
          child: const AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 23),
            minFontSize: 12,
            stepGranularity: 5,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets('should preserve the historical 12 through 60 domain', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 60,
        widget: const AutoSizeText(
          '',
          style: TextStyle(fontSize: 60),
          minFontSize: 12,
          maxFontSize: 60,
          stepGranularity: 1,
        ),
      );

      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 12,
        widget: const SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 60),
            minFontSize: 12,
            maxFontSize: 60,
            stepGranularity: 1,
            maxLines: 1,
          ),
        ),
      );
    });

    testWidgets(
      'should keep only the exact upper bound for a quasi-equal span',
      (tester) async {
        const upper = 1.0000000000000009;

        await pumpAndExpectFontSize(
          tester: tester,
          expectedFontSize: upper,
          widget: const SizedBox(
            width: 0,
            height: 0,
            child: AutoSizeText(
              'XXXXX',
              style: TextStyle(fontSize: upper),
              minFontSize: 1,
              stepGranularity: 0.1,
              maxLines: 1,
            ),
          ),
        );
      },
    );

    testWidgets('should reject a grid whose floating candidates alias', (
      tester,
    ) async {
      const minimum = 1000000000000000.0;

      await _expectArgumentError(
        tester,
        const AutoSizeText(
          'XXXXX',
          style: TextStyle(fontSize: minimum + 10),
          minFontSize: minimum,
          maxFontSize: minimum + 10,
          stepGranularity: 0.1,
        ),
      );
    });

    testWidgets('should reject a non-representable candidate ratio', (
      tester,
    ) async {
      await _expectArgumentError(
        tester,
        const AutoSizeText(
          'XXXXX',
          style: TextStyle(fontSize: double.maxFinite),
          minFontSize: 0,
          maxFontSize: double.infinity,
          stepGranularity: 0.1,
        ),
      );
    });

    testWidgets('should evaluate a huge candidate ratio in logarithmic count', (
      tester,
    ) async {
      var buildCount = 0;

      await pump(
        tester: tester,
        widget: SizedBox(
          width: 0,
          height: 0,
          child: AutoSizeText.rich(
            TextSpan(
              children: <InlineSpan>[_CountingTextSpan(() => buildCount += 1)],
            ),
            style: const TextStyle(fontSize: 100000000),
            minFontSize: 0.1,
            stepGranularity: 0.1,
            maxLines: 1,
            overflowReplacement: const SizedBox.shrink(),
          ),
        ),
      );

      expect(buildCount, greaterThan(0));
      expect(buildCount, lessThanOrEqualTo(40));
    });
  });
}

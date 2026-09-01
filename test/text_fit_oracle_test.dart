import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

Future<RenderParagraph> _pumpText(
  WidgetTester tester, {
  required Text text,
  required double width,
  MediaQueryData mediaQueryData = const MediaQueryData(),
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: mediaQueryData,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: text),
        ),
      ),
    ),
  );

  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

void main() {
  group('text fit oracle', () {
    testWidgets('rejects an emergency word break with unlimited lines', (
      tester,
    ) async {
      const text = Text(
        'AAAA',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      );
      final paragraph = await _pumpText(tester, text: text, width: 25);

      expect(paragraph.maxLines, isNull);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(doesTextFit(text, 25, double.infinity, false), isFalse);
    });

    test('rejects a non-positive maximum line count', () {
      const text = Text(
        'A',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 0,
      );

      expect(
        () => doesTextFit(text, 100, double.infinity, false),
        throwsAssertionError,
      );
    });

    testWidgets('uses ambient direction and text scaling', (tester) async {
      const text = Text(
        'AAAA',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
        maxLines: 1,
      );
      final paragraph = await _pumpText(
        tester,
        text: text,
        width: 50,
        mediaQueryData: const MediaQueryData(textScaler: TextScaler.linear(2)),
      );

      expect(paragraph.textDirection, TextDirection.ltr);
      expect(paragraph.textScaler.scale(10), 20);
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(doesTextFit(text, 50), isFalse);
    });

    testWidgets('uses the ambient line-height override in strut', (
      tester,
    ) async {
      const text = Text(
        'A',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        strutStyle: StrutStyle(
          fontFamily: 'Ahem',
          fontSize: 20,
          forceStrutHeight: true,
        ),
      );
      final paragraph = await _pumpText(
        tester,
        text: text,
        width: 100,
        mediaQueryData: const MediaQueryData(
          lineHeightScaleFactorOverride: 0.5,
        ),
      );

      expect(paragraph.strutStyle?.height, 0.5);
      expect(paragraph.size.height, lessThanOrEqualTo(15));
      expect(doesTextFit(text, 100, 15), isTrue);
    });
  });
}

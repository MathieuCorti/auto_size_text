import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

Future<RenderParagraph> _pumpText(
  WidgetTester tester, {
  required Text text,
  required double width,
  double maxHeight = double.infinity,
  MediaQueryData mediaQueryData = const MediaQueryData(),
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: mediaQueryData,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
            child: text,
          ),
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
      expect(renderParagraphFits(paragraph, wrapWords: false), isFalse);
    });

    testWidgets('rejects a non-positive maximum line count', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            'A',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
            textScaler: TextScaler.noScaling,
            maxLines: 0,
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('uses ambient direction and text scaling', (tester) async {
      const text = Text(
        'AAAA',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
        locale: Locale('en', 'US'),
        maxLines: 1,
        textWidthBasis: TextWidthBasis.longestLine,
        textHeightBehavior: TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      );
      final paragraph = await _pumpText(
        tester,
        text: text,
        width: 50,
        mediaQueryData: const MediaQueryData(textScaler: TextScaler.linear(2)),
      );

      expect(paragraph.textDirection, TextDirection.ltr);
      expect(paragraph.locale, const Locale('en', 'US'));
      expect(paragraph.textScaler.scale(10), 20);
      expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
      expect(
        paragraph.textHeightBehavior,
        const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(renderParagraphFits(paragraph), isFalse);
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
        maxHeight: 15,
        mediaQueryData: const MediaQueryData(
          lineHeightScaleFactorOverride: 0.5,
        ),
      );

      expect(paragraph.strutStyle?.height, 0.5);
      expect(paragraph.size.height, lessThanOrEqualTo(15));
      expect(renderParagraphFits(paragraph), isTrue);

      final tighterParagraph = await _pumpText(
        tester,
        text: text,
        width: 100,
        maxHeight: 7,
        mediaQueryData: const MediaQueryData(
          lineHeightScaleFactorOverride: 0.5,
        ),
      );
      expect(renderParagraphFits(tighterParagraph), isFalse);
    });
  });
}

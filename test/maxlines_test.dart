import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

void main() {
  group('AutoSizeText maxLines', () {
    testWidgets('should respect an explicit maximum line count', (
      tester,
    ) async {
      await pump(
        tester: tester,
        widget: AutoSizeText(
          'XXXXX',
          style: TextStyle(fontSize: 27),
          maxLines: 1,
        ),
      );
      var height = tester.getSize(find.byType(RichText)).height;
      expect(height, 27);

      await pump(
        tester: tester,
        widget: SizedBox(
          width: 75,
          child: AutoSizeText(
            'XXX XXX',
            style: TextStyle(fontSize: 25),
            maxLines: 2,
          ),
        ),
      );
      height = tester.getSize(find.byType(RichText)).height;
      expect(height, 50);
    });

    testWidgets('should allow unlimited lines when maxLines is null', (
      tester,
    ) async {
      await pump(
        tester: tester,
        widget: SizedBox(
          width: 50,
          child: AutoSizeText(
            'AAAA AAAA',
            style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
            presetFontSizes: const <double>[20],
            textScaler: TextScaler.noScaling,
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(paragraph.size.height, greaterThan(20));
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('should honor the wrapWords line bound in the fit helper', (
      tester,
    ) async {
      await pump(
        tester: tester,
        widget: const SizedBox(
          width: 10,
          child: Text(
            'A A A A A',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 10),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            maxLines: 4,
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );

      expect(paragraph.maxLines, 4);
      expect(renderParagraphFits(paragraph, wrapWords: false), isFalse);
    });
  });
}

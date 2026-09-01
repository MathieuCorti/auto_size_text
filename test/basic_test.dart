import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

void main() {
  group('AutoSizeText', () {
    testWidgets('should render plain text', (tester) async {
      await pump(tester: tester, widget: AutoSizeText('Some Text'));
    });

    testWidgets('should render rich text', (tester) async {
      await pump(
        tester: tester,
        widget: AutoSizeText.rich(TextSpan(text: 'Some Text')),
      );
    });

    testWidgets('should use style fontSize', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 34,
        widget: AutoSizeText('Some Text', style: TextStyle(fontSize: 34)),
      );
    });

    testWidgets('should use style fontSize for rich text', (tester) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 35,
        widget: AutoSizeText.rich(
          TextSpan(text: 'Some Text'),
          style: TextStyle(fontSize: 35),
        ),
      );
    });

    testWidgets('should respect inherited style', (tester) async {
      final defaultStyle = TextStyle(fontSize: 20, color: Colors.yellow);
      final text = await pumpAndGetText(
        tester: tester,
        widget: DefaultTextStyle(
          style: defaultStyle,
          textAlign: TextAlign.right,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          maxLines: 17,
          child: AutoSizeText('AutoSizeText Test'),
        ),
      );
      expect(text.style, isNull);

      final richText = getRichText(tester);
      expect(richText.text.style, defaultStyle);
      expect(richText.textAlign, TextAlign.right);
      expect(richText.softWrap, false);
      expect(richText.overflow, TextOverflow.ellipsis);
      expect(richText.maxLines, 17);
    });

    testWidgets('should apply scale even if initial fontSize fits (#25)', (
      tester,
    ) async {
      await pumpAndExpectFontSize(
        tester: tester,
        expectedFontSize: 60,
        widget: AutoSizeText(
          'Some Text',
          style: TextStyle(fontSize: 15),
          textScaleFactor: 4,
        ),
      );
    });

    testWidgets('should use textKey', (tester) async {
      final textKey = GlobalKey();
      final text = await pumpAndGetText(
        tester: tester,
        widget: AutoSizeText('A text with key', textKey: textKey),
      );
      expect(text.key, textKey);
    });
  });
}

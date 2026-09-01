import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final class _PlainTextCounter {
  int calls = 0;
}

final class _CountingTextSpan extends TextSpan {
  const _CountingTextSpan(this.counter, {required super.text});

  final _PlainTextCounter counter;

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    counter.calls += 1;
    super.computeToPlainText(
      buffer,
      includeSemanticsLabels: includeSemanticsLabels,
      includePlaceholders: includePlaceholders,
    );
  }
}

Future<RenderParagraph> _pumpRich(
  WidgetTester tester, {
  required TextSpan source,
  required double width,
  String? semanticsLabel,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(
            width: width,
            height: 200,
            child: AutoSizeText.rich(
              source,
              style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
              presetFontSizes: const <double>[20, 10],
              textScaler: TextScaler.noScaling,
              maxLines: 10,
              wrapWords: false,
              semanticsLabel: semanticsLabel,
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

double _rootSize(RenderParagraph paragraph) =>
    paragraph.textScaler.scale(paragraph.text.style!.fontSize!);

double _selectionWidth(RenderParagraph paragraph, int start, int end) =>
    paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        )
        .fold<double>(0, (width, box) => width + (box.right - box.left).abs());

List<TextBox> _witnessBoxes(
  TextSpan source, {
  required double candidate,
  TextDirection direction = TextDirection.ltr,
}) {
  final text = TextSpan(
    style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
    children: <InlineSpan>[source],
  );
  final plainText = text.toPlainText(includeSemanticsLabels: false);
  final painter = TextPainter(
    text: text,
    textDirection: direction,
    textScaler: TextScaler.linear(candidate / 20),
  );
  try {
    painter.layout(maxWidth: double.infinity);
    return painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: plainText.length),
    );
  } finally {
    painter.dispose();
  }
}

double _witnessWidth(
  TextSpan source, {
  required double candidate,
  TextDirection direction = TextDirection.ltr,
}) => _witnessBoxes(
  source,
  candidate: candidate,
  direction: direction,
).fold<double>(0, (width, box) => width + (box.right - box.left).abs());

void main() {
  group('AutoSizeText wrapWords', () {
    testWidgets('should preserve historical plain-text word fitting', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: AutoSizeText(
                'XXXXX XXXXX',
                style: TextStyle(fontFamily: 'Ahem', fontSize: 25),
                textScaler: TextScaler.noScaling,
                wrapWords: false,
              ),
            ),
          ),
        ),
      );
      var paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      expect(_rootSize(paragraph), 20);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 40,
              height: 100,
              child: AutoSizeText(
                'XXXXX',
                style: TextStyle(fontFamily: 'Ahem', fontSize: 25),
                minFontSize: 10,
                textScaler: TextScaler.noScaling,
                maxLines: 10,
                wrapWords: false,
              ),
            ),
          ),
        ),
      );
      paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
      expect(_rootSize(paragraph), 10);
    });

    testWidgets(
      'should keep spaces tabs and newlines as historical opportunities',
      (tester) async {
        for (final separator in <String>[' ', '\t', '\n', '\r\n']) {
          final paragraph = await _pumpRich(
            tester,
            source: TextSpan(text: 'AA${separator}AA'),
            width: 55,
          );
          expect(
            _rootSize(paragraph),
            20,
            reason: separator.codeUnits.toString(),
          );
        }
      },
    );

    testWidgets('should keep NBSP and NNBSP inside an unbreakable range', (
      tester,
    ) async {
      for (final separator in <String>['\u00A0', '\u202F']) {
        final paragraph = await _pumpRich(
          tester,
          source: TextSpan(text: 'AA${separator}AA'),
          width: 55,
        );
        expect(
          _rootSize(paragraph),
          10,
          reason: separator.codeUnits.toString(),
        );
        expect(_selectionWidth(paragraph, 0, 5), lessThanOrEqualTo(55));
      }
    });

    testWidgets('should ignore empty ranges around consecutive separators', (
      tester,
    ) async {
      final paragraph = await _pumpRich(
        tester,
        source: const TextSpan(text: ' \t\nAA  \r\nBB\t '),
        width: 55,
      );

      expect(_rootSize(paragraph), 20);
    });

    testWidgets('should preserve runs when one word crosses multiple spans', (
      tester,
    ) async {
      const source = TextSpan(
        text: 'A',
        children: <InlineSpan>[
          TextSpan(text: 'A', style: TextStyle(fontSize: 40)),
          TextSpan(
            text: 'A',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
      final paragraph = await _pumpRich(tester, source: source, width: 50);

      expect(_rootSize(paragraph), 10);
      expect(_selectionWidth(paragraph, 0, 3), 40);
    });

    testWidgets(
      'should measure mixed linked ranges without normalizing source text',
      (tester) async {
        const source = TextSpan(
          text: 'AA\u00A0BB CC\u202FDD',
          children: <InlineSpan>[
            TextSpan(text: ' '),
            TextSpan(text: '\tEE\nFF'),
          ],
        );
        final paragraph = await _pumpRich(tester, source: source, width: 55);

        expect(_rootSize(paragraph), 10);
        expect(
          paragraph.text.toPlainText(includeSemanticsLabels: false),
          source.toPlainText(includeSemanticsLabels: false),
        );
      },
    );

    testWidgets(
      'should use visual UTF-16 offsets instead of semantics labels',
      (tester) async {
        const source = TextSpan(
          text: '\u{1F600}\u00A0',
          semanticsLabel: 'emoji break ',
          children: <InlineSpan>[
            TextSpan(text: 'AA', semanticsLabel: 'separate words'),
          ],
        );
        final widthAt20 = _witnessWidth(source, candidate: 20);
        final widthAt10 = _witnessWidth(source, candidate: 10);
        expect(widthAt20, greaterThan(widthAt10));
        final maxWidth = (widthAt20 + widthAt10) / 2;

        final paragraph = await _pumpRich(
          tester,
          source: source,
          width: maxWidth,
        );

        expect(_rootSize(paragraph), 10);
        expect(_selectionWidth(paragraph, 0, 5), lessThanOrEqualTo(maxWidth));
      },
    );

    testWidgets('should aggregate every bidi box in a linked visual range', (
      tester,
    ) async {
      const source = TextSpan(text: 'A\u00A0אב');
      final boxesAt20 = _witnessBoxes(source, candidate: 20);
      final widthAt20 = boxesAt20.fold<double>(
        0,
        (width, box) => width + (box.right - box.left).abs(),
      );
      final widthAt10 = _witnessWidth(source, candidate: 10);
      final maxWidth = (widthAt20 + widthAt10) / 2;

      expect(boxesAt20, hasLength(greaterThan(1)));
      expect(
        widthAt20,
        greaterThan(
          boxesAt20
              .map((box) => (box.right - box.left).abs())
              .reduce((first, second) => first > second ? first : second),
        ),
      );

      final paragraph = await _pumpRich(
        tester,
        source: source,
        width: maxWidth,
      );
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      expect(_rootSize(paragraph), 10);
      expect(boxes, hasLength(greaterThan(1)));
      expect(
        boxes.fold<double>(
          0,
          (width, box) => width + (box.right - box.left).abs(),
        ),
        lessThanOrEqualTo(maxWidth),
      );
    });

    testWidgets(
      'should handle an alternating separator corpus without changing words',
      (tester) async {
        final text = List<String>.generate(
          256,
          (index) => index.isEven ? 'A' : ' ',
        ).join();
        final source = TextSpan(text: text);
        final paragraph = await _pumpRich(tester, source: source, width: 700);

        expect(_rootSize(paragraph), 20);
        expect(paragraph.text.toPlainText(includeSemanticsLabels: false), text);
      },
    );

    testWidgets(
      'should segment once per configuration outside candidate search',
      (tester) async {
        final counter = _PlainTextCounter();
        final firstSource = _CountingTextSpan(counter, text: 'A');

        Future<void> pumpConfiguration({
          required TextSpan source,
          required bool wrapWords,
          double? letterSpacingOverride,
        }) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.noScaling,
                letterSpacingOverride: letterSpacingOverride,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                  width: 0,
                  height: 0,
                  child: AutoSizeText.rich(
                    source,
                    style: const TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 100000000,
                    ),
                    minFontSize: 0.1,
                    stepGranularity: 0.1,
                    textScaler: TextScaler.noScaling,
                    softWrap: false,
                    maxLines: 1,
                    wrapWords: wrapWords,
                    overflowReplacement: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        }

        await pumpConfiguration(source: firstSource, wrapWords: true);
        expect(counter.calls, 0);

        await pumpConfiguration(source: firstSource, wrapWords: false);
        expect(counter.calls, 1);

        await pumpConfiguration(
          source: firstSource,
          wrapWords: false,
          letterSpacingOverride: 1,
        );
        expect(counter.calls, 2);

        final secondSource = _CountingTextSpan(counter, text: 'B');
        await pumpConfiguration(source: secondSource, wrapWords: false);
        expect(counter.calls, 3);
      },
    );

    testWidgets(
      'should preserve wrapWords true behavior for an emergency break',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 90,
                child: AutoSizeText(
                  'XXXXXX',
                  style: TextStyle(fontFamily: 'Ahem', fontSize: 40),
                  textScaler: TextScaler.noScaling,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );

        expect(_rootSize(paragraph), 30);
        expect(paragraph.size.height, 60);
      },
    );
  });
}

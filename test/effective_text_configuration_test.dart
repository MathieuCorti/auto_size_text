import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RenderParagraph> _pumpParagraph(
  WidgetTester tester, {
  required Widget child,
  MediaQueryData mediaQueryData = const MediaQueryData(),
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  TextStyle defaultStyle = const TextStyle(fontFamily: 'Ahem', fontSize: 20),
  TextAlign? defaultAlign,
  bool defaultSoftWrap = true,
  TextOverflow defaultOverflow = TextOverflow.clip,
  int? defaultMaxLines,
  TextWidthBasis defaultWidthBasis = TextWidthBasis.parent,
  TextHeightBehavior? defaultHeightBehavior,
  TextHeightBehavior? ambientHeightBehavior,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: mediaQueryData.copyWith(textScaler: TextScaler.noScaling),
      child: Localizations(
        locale: locale,
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: direction,
          child: DefaultTextHeightBehavior(
            textHeightBehavior:
                ambientHeightBehavior ?? const TextHeightBehavior(),
            child: DefaultTextStyle(
              style: defaultStyle,
              textAlign: defaultAlign,
              softWrap: defaultSoftWrap,
              overflow: defaultOverflow,
              maxLines: defaultMaxLines,
              textWidthBasis: defaultWidthBasis,
              textHeightBehavior: defaultHeightBehavior,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

void _expectPainterMatchesRenderParagraph(
  RenderParagraph paragraph, {
  double? referenceFontSize,
  double minFontSize = 12,
}) {
  final constraints = paragraph.constraints;
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  );

  try {
    painter.layout(
      minWidth: constraints.minWidth,
      maxWidth:
          paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
          ? constraints.maxWidth
          : double.infinity,
    );

    expect(painter.size, paragraph.textSize);
    expect(painter.didExceedMaxLines, paragraph.didExceedMaxLines);
    expect(paragraph.size, constraints.constrain(painter.size));
  } finally {
    painter.dispose();
  }

  if (referenceFontSize != null) {
    expect(
      _rootSize(paragraph),
      _largestFittingCandidate(
        paragraph,
        referenceFontSize: referenceFontSize,
        minFontSize: minFontSize,
      ),
    );
  }
}

double _rootSize(RenderParagraph paragraph) =>
    paragraph.textScaler.scale(paragraph.text.style!.fontSize!);

double _largestFittingCandidate(
  RenderParagraph paragraph, {
  required double referenceFontSize,
  required double minFontSize,
}) {
  final sourceText = paragraph.text as TextSpan;
  final witnessText = TextSpan(
    style: sourceText.style!.copyWith(fontSize: referenceFontSize),
    text: sourceText.text,
    children: sourceText.children,
    locale: sourceText.locale,
  );
  final constraints = paragraph.constraints;

  for (
    var candidate = referenceFontSize;
    candidate >= minFontSize;
    candidate -= 1
  ) {
    final painter = TextPainter(
      text: witnessText,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: TextScaler.linear(candidate / referenceFontSize),
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    );

    try {
      painter.layout(
        minWidth: constraints.minWidth,
        maxWidth:
            paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
            ? constraints.maxWidth
            : double.infinity,
      );
      final textSize = painter.size;
      final renderSize = constraints.constrain(textSize);
      if (!painter.didExceedMaxLines &&
          renderSize.width >= textSize.width &&
          renderSize.height >= textSize.height) {
        return candidate;
      }
    } finally {
      painter.dispose();
    }
  }

  return minFontSize;
}

void main() {
  group('AutoSizeText effective text configuration', () {
    testWidgets(
      'should merge inherited styles and preserve the historical fallback',
      (tester) async {
        var paragraph = await _pumpParagraph(
          tester,
          defaultStyle: const TextStyle(fontFamily: 'Ahem', fontSize: 30),
          child: const AutoSizeText('', style: TextStyle(color: Colors.red)),
        );
        expect(_rootSize(paragraph), 30);
        expect(paragraph.text.style!.color, Colors.red);
        _expectPainterMatchesRenderParagraph(paragraph);

        paragraph = await _pumpParagraph(
          tester,
          defaultStyle: const TextStyle(fontFamily: 'Ahem', fontSize: 30),
          child: const AutoSizeText(
            '',
            style: TextStyle(inherit: false, fontSize: 25),
          ),
        );
        expect(_rootSize(paragraph), 25);
        _expectPainterMatchesRenderParagraph(paragraph);

        paragraph = await _pumpParagraph(
          tester,
          defaultStyle: const TextStyle(fontFamily: 'Ahem'),
          child: const AutoSizeText(''),
        );
        expect(_rootSize(paragraph), 14);
        _expectPainterMatchesRenderParagraph(paragraph);
      },
    );

    testWidgets('should replace the effective weight with bold w700', (
      tester,
    ) async {
      final paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(boldText: true),
        child: const SizedBox(
          width: 170,
          child: AutoSizeText(
            'XXXXXX',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
            minFontSize: 10,
            maxLines: 1,
          ),
        ),
      );

      expect(paragraph.text.style!.fontWeight, FontWeight.bold);
      _expectPainterMatchesRenderParagraph(
        paragraph,
        referenceFontSize: 30,
        minFontSize: 10,
      );
    });

    testWidgets(
      'should replace all three spacing overrides and refresh between pumps',
      (tester) async {
        const textKey = ValueKey<String>('overridden text');
        var paragraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(
            lineHeightScaleFactorOverride: 1.5,
            letterSpacingOverride: 7,
            wordSpacingOverride: 11,
          ),
          child: const SizedBox(
            width: 260,
            height: 100,
            child: AutoSizeText(
              'XX XX',
              textKey: textKey,
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 30,
                height: 3,
                letterSpacing: 2,
                wordSpacing: 4,
              ),
              minFontSize: 10,
              maxLines: 1,
            ),
          ),
        );
        final firstTextSize = paragraph.textSize;
        expect(paragraph.text.style!.height, 1.5);
        expect(paragraph.text.style!.letterSpacing, 7);
        expect(paragraph.text.style!.wordSpacing, 11);
        final sourceText = tester.widget<Text>(find.byKey(textKey));
        expect(sourceText.style!.height, 3);
        expect(sourceText.style!.letterSpacing, 2);
        expect(sourceText.style!.wordSpacing, 4);
        _expectPainterMatchesRenderParagraph(
          paragraph,
          referenceFontSize: 30,
          minFontSize: 10,
        );

        paragraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(
            lineHeightScaleFactorOverride: 0.8,
            letterSpacingOverride: 1,
            wordSpacingOverride: 2,
          ),
          child: const SizedBox(
            width: 260,
            height: 100,
            child: AutoSizeText(
              'XX XX',
              textKey: textKey,
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 30,
                height: 3,
                letterSpacing: 2,
                wordSpacing: 4,
              ),
              minFontSize: 10,
              maxLines: 1,
            ),
          ),
        );
        expect(paragraph.text.style!.height, 0.8);
        expect(paragraph.text.style!.letterSpacing, 1);
        expect(paragraph.text.style!.wordSpacing, 2);
        expect(paragraph.textSize, isNot(firstTextSize));
        _expectPainterMatchesRenderParagraph(
          paragraph,
          referenceFontSize: 30,
          minFontSize: 10,
        );
      },
    );

    testWidgets('should measure every text metric override in isolation', (
      tester,
    ) async {
      var paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(
          lineHeightScaleFactorOverride: 1.5,
        ),
        child: const SizedBox(
          width: 300,
          height: 35,
          child: AutoSizeText(
            'XX',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 30, height: 0.5),
            minFontSize: 10,
            maxLines: 1,
          ),
        ),
      );
      expect(paragraph.text.style!.height, 1.5);
      _expectPainterMatchesRenderParagraph(
        paragraph,
        referenceFontSize: 30,
        minFontSize: 10,
      );

      paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(letterSpacingOverride: 10),
        child: const SizedBox(
          width: 170,
          height: 100,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(
              fontFamily: 'Ahem',
              fontSize: 30,
              letterSpacing: 0,
            ),
            minFontSize: 10,
            maxLines: 1,
          ),
        ),
      );
      expect(paragraph.text.style!.letterSpacing, 10);
      _expectPainterMatchesRenderParagraph(
        paragraph,
        referenceFontSize: 30,
        minFontSize: 10,
      );

      paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(wordSpacingOverride: 20),
        child: const SizedBox(
          width: 180,
          height: 100,
          child: AutoSizeText(
            'X X X',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 30, wordSpacing: 0),
            minFontSize: 10,
            maxLines: 1,
          ),
        ),
      );
      expect(paragraph.text.style!.wordSpacing, 20);
      _expectPainterMatchesRenderParagraph(
        paragraph,
        referenceFontSize: 30,
        minFontSize: 10,
      );
    });

    testWidgets(
      'should merge a supplied strut only and drive overflow replacement',
      (tester) async {
        const replacementKey = ValueKey<String>('replacement');
        const textKey = ValueKey<String>('strut text');
        await _pumpParagraph(
          tester,
          child: const SizedBox(
            width: 200,
            height: 60,
            child: AutoSizeText(
              'XXXXX',
              textKey: textKey,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              strutStyle: StrutStyle(
                fontSize: 100,
                height: 1,
                forceStrutHeight: true,
              ),
              minFontSize: 20,
              overflowReplacement: Text('replacement', key: replacementKey),
            ),
          ),
        );
        expect(find.byKey(replacementKey), findsOneWidget);

        final paragraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(
            lineHeightScaleFactorOverride: 0.5,
          ),
          child: const SizedBox(
            width: 200,
            height: 60,
            child: AutoSizeText(
              'XXXXX',
              textKey: textKey,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              strutStyle: StrutStyle(
                fontSize: 100,
                height: 1,
                forceStrutHeight: true,
              ),
              minFontSize: 20,
              overflowReplacement: Text('replacement', key: replacementKey),
            ),
          ),
        );
        expect(find.byKey(replacementKey), findsNothing);
        expect(paragraph.strutStyle!.height, 0.5);
        expect(tester.widget<Text>(find.byKey(textKey)).strutStyle!.height, 1);
        _expectPainterMatchesRenderParagraph(
          paragraph,
          referenceFontSize: 20,
          minFontSize: 20,
        );

        final paragraphWithoutStrut = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(
            lineHeightScaleFactorOverride: 0.5,
          ),
          child: const AutoSizeText('no strut'),
        );
        expect(paragraphWithoutStrut.strutStyle, isNull);
      },
    );

    testWidgets(
      'should distinguish inherited wrap, clip, and ellipsis width rules',
      (tester) async {
        const replacementKey = ValueKey<String>('replacement');
        await _pumpParagraph(
          tester,
          defaultSoftWrap: false,
          child: const SizedBox(
            width: 200,
            height: 100,
            child: AutoSizeText(
              'XXXXX XXXXX',
              style: TextStyle(fontFamily: 'Ahem', fontSize: 30),
              minFontSize: 30,
              overflowReplacement: Text('replacement', key: replacementKey),
            ),
          ),
        );
        expect(find.byKey(replacementKey), findsOneWidget);

        final wrapped = await _pumpParagraph(
          tester,
          defaultSoftWrap: false,
          child: const SizedBox(
            width: 200,
            height: 100,
            child: AutoSizeText(
              'XXXXX XXXXX',
              style: TextStyle(fontFamily: 'Ahem', fontSize: 30),
              minFontSize: 30,
              softWrap: true,
            ),
          ),
        );
        expect(wrapped.softWrap, isTrue);
        expect(wrapped.textSize.width, lessThanOrEqualTo(200));
        _expectPainterMatchesRenderParagraph(
          wrapped,
          referenceFontSize: 30,
          minFontSize: 30,
        );

        final ellipsized = await _pumpParagraph(
          tester,
          defaultSoftWrap: false,
          child: const SizedBox(
            width: 200,
            height: 40,
            child: AutoSizeText(
              'XXXXX XXXXX',
              style: TextStyle(
                fontFamily: 'Ahem',
                fontSize: 30,
                overflow: TextOverflow.ellipsis,
              ),
              minFontSize: 30,
              softWrap: false,
              maxLines: 1,
            ),
          ),
        );
        expect(ellipsized.didExceedMaxLines, isTrue);
        expect(ellipsized.textSize.width, 200);
        _expectPainterMatchesRenderParagraph(
          ellipsized,
          referenceFontSize: 30,
          minFontSize: 30,
        );
      },
    );

    testWidgets(
      'should honor nonzero minWidth, direction, locale, and paragraph defaults',
      (tester) async {
        const defaultBehavior = TextHeightBehavior(
          applyHeightToFirstAscent: false,
        );
        var paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          locale: const Locale('th'),
          defaultAlign: TextAlign.end,
          defaultWidthBasis: TextWidthBasis.longestLine,
          defaultHeightBehavior: defaultBehavior,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
            child: const AutoSizeText('ข้อความ'),
          ),
        );
        expect(paragraph.textDirection, TextDirection.rtl);
        expect(paragraph.locale, const Locale('th'));
        expect(paragraph.textAlign, TextAlign.end);
        expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
        expect(paragraph.textHeightBehavior, defaultBehavior);
        expect(paragraph.textSize.width, greaterThanOrEqualTo(120));
        _expectPainterMatchesRenderParagraph(paragraph, referenceFontSize: 20);

        const explicitBehavior = TextHeightBehavior(
          applyHeightToLastDescent: false,
        );
        paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          locale: const Locale('th'),
          defaultHeightBehavior: null,
          ambientHeightBehavior: explicitBehavior,
          child: const AutoSizeText(
            'explicit',
            textDirection: TextDirection.ltr,
            locale: Locale('en'),
            textAlign: TextAlign.center,
          ),
        );
        expect(paragraph.textDirection, TextDirection.ltr);
        expect(paragraph.locale, const Locale('en'));
        expect(paragraph.textAlign, TextAlign.center);
        expect(paragraph.textHeightBehavior, explicitBehavior);
        _expectPainterMatchesRenderParagraph(paragraph, referenceFontSize: 20);
      },
    );
  });
}

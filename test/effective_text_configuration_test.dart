import 'dart:io';
import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _localeFixtureFamily = 'AutoSizeTextMetricNaskh';
const _robotoFixtureFamily = 'AutoSizeTextMetricRoboto';

Future<ByteData> _readFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> _loadMetricFixtures() async {
  final localeLoader = FontLoader(_localeFixtureFamily)
    ..addFont(_readFont('test/assets/fonts/auto_size_metric_naskh_locl.ttf'));
  final robotoLoader = FontLoader(_robotoFixtureFamily)
    ..addFont(
      _readFont('test/assets/fonts/auto_size_metric_roboto_regular.ttf'),
    )
    ..addFont(_readFont('test/assets/fonts/auto_size_metric_roboto_bold.ttf'));

  await Future.wait(<Future<void>>[localeLoader.load(), robotoLoader.load()]);
}

final class _PainterWitness {
  const _PainterWitness({
    required this.size,
    required this.baseline,
    required this.lineWidth,
    required this.didExceedMaxLines,
  });

  final Size size;
  final double baseline;
  final double lineWidth;
  final bool didExceedMaxLines;
}

_PainterWitness _measureWitness({
  required String text,
  required TextStyle style,
  BoxConstraints constraints = const BoxConstraints(),
  TextDirection direction = TextDirection.ltr,
  Locale? locale,
  TextHeightBehavior? heightBehavior,
  TextAlign textAlign = TextAlign.start,
  TextWidthBasis widthBasis = TextWidthBasis.parent,
  int? maxLines = 1,
  double? candidate,
  bool softWrap = true,
}) {
  final reference = style.fontSize!;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: direction,
    textScaler: candidate == null
        ? TextScaler.noScaling
        : TextScaler.linear(candidate / reference),
    maxLines: maxLines,
    locale: locale,
    textWidthBasis: widthBasis,
    textHeightBehavior: heightBehavior,
  );

  try {
    painter.layout(
      minWidth: constraints.minWidth,
      maxWidth: softWrap ? constraints.maxWidth : double.infinity,
    );
    final line = painter.computeLineMetrics().single;
    return _PainterWitness(
      size: painter.size,
      baseline: painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      ),
      lineWidth: line.width,
      didExceedMaxLines: painter.didExceedMaxLines,
    );
  } finally {
    painter.dispose();
  }
}

double _largestWitnessCandidate({
  required String text,
  required TextStyle style,
  required BoxConstraints constraints,
  TextDirection direction = TextDirection.ltr,
  Locale? locale,
  TextHeightBehavior? heightBehavior,
  TextAlign textAlign = TextAlign.start,
  TextWidthBasis widthBasis = TextWidthBasis.parent,
  double minFontSize = 10,
  List<double>? presetFontSizes,
  bool softWrap = true,
}) {
  final reference = style.fontSize!;
  final candidates =
      presetFontSizes ??
      <double>[
        for (
          var candidate = reference;
          candidate >= minFontSize;
          candidate -= 1
        )
          candidate,
      ];
  for (final candidate in candidates) {
    final witness = _measureWitness(
      text: text,
      style: style,
      constraints: constraints,
      direction: direction,
      locale: locale,
      heightBehavior: heightBehavior,
      textAlign: textAlign,
      widthBasis: widthBasis,
      candidate: candidate,
      softWrap: softWrap,
    );
    final constrainedSize = constraints.constrain(witness.size);
    if (!witness.didExceedMaxLines &&
        constrainedSize.width >= witness.size.width &&
        constrainedSize.height >= witness.size.height) {
      return candidate;
    }
  }
  return minFontSize;
}

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
    setUpAll(_loadMetricFixtures);

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
      const text = 'MMMMMM';
      const sourceStyle = TextStyle(
        inherit: false,
        fontFamily: _robotoFixtureFamily,
        fontSize: 30,
        fontWeight: FontWeight.w400,
      );
      final boldStyle = sourceStyle.copyWith(fontWeight: FontWeight.bold);
      final sourceWidth = _measureWitness(
        text: text,
        style: sourceStyle,
      ).size.width;
      final boldWidth = _measureWitness(
        text: text,
        style: boldStyle,
      ).size.width;
      expect(sourceWidth, isNot(closeTo(boldWidth, 0.01)));

      final width = (sourceWidth + boldWidth) / 2;
      final constraints = BoxConstraints.tightFor(width: width, height: 100);
      final sourceCandidate = _largestWitnessCandidate(
        text: text,
        style: sourceStyle,
        constraints: constraints,
        presetFontSizes: const <double>[30, 29],
      );
      final boldCandidate = _largestWitnessCandidate(
        text: text,
        style: boldStyle,
        constraints: constraints,
        presetFontSizes: const <double>[30, 29],
      );
      expect(<double>[
        sourceCandidate,
        boldCandidate,
      ], orderedEquals(<double>[30, 29]));

      var paragraph = await _pumpParagraph(
        tester,
        child: SizedBox(
          width: width,
          height: 100,
          child: const AutoSizeText(
            text,
            style: sourceStyle,
            presetFontSizes: <double>[30, 29],
            maxLines: 1,
          ),
        ),
      );
      expect(paragraph.text.style!.fontWeight, FontWeight.w400);
      expect(_rootSize(paragraph), sourceCandidate);

      paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(boldText: true),
        child: SizedBox(
          width: width,
          height: 100,
          child: AutoSizeText(
            text,
            style: sourceStyle,
            presetFontSizes: const <double>[30, 29],
            maxLines: 1,
          ),
        ),
      );

      expect(paragraph.text.style!.fontWeight, FontWeight.bold);
      expect(_rootSize(paragraph), boldCandidate);
      _expectPainterMatchesRenderParagraph(
        paragraph,
        referenceFontSize: 30,
        minFontSize: 10,
      );
    });

    testWidgets('should replace an existing heavy weight exactly with w700', (
      tester,
    ) async {
      final paragraph = await _pumpParagraph(
        tester,
        mediaQueryData: const MediaQueryData(boldText: true),
        child: const AutoSizeText(
          'MMMMMM',
          style: TextStyle(
            inherit: false,
            fontFamily: _robotoFixtureFamily,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

      expect(paragraph.text.style!.fontWeight, FontWeight.bold);
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
        _expectPainterMatchesRenderParagraph(paragraph);

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
      'should measure inherited and explicit direction with different widths',
      (tester) async {
        const text = '<<<<<<';
        const style = TextStyle(
          inherit: false,
          fontFamily: _robotoFixtureFamily,
          fontSize: 30,
        );
        final ltrWitness = _measureWitness(text: text, style: style);
        final rtlWitness = _measureWitness(
          text: text,
          style: style,
          direction: TextDirection.rtl,
        );
        final ltrWidth = ltrWitness.size.width;
        final rtlWidth = rtlWitness.size.width;
        expect(ltrWidth, isNot(closeTo(rtlWidth, 0.01)));
        expect(
          ltrWitness.lineWidth,
          isNot(closeTo(rtlWitness.lineWidth, 0.01)),
        );

        final width = (ltrWidth + rtlWidth) / 2;
        final constraints = BoxConstraints.tightFor(width: width, height: 100);
        final ltrCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          presetFontSizes: const <double>[30, 29],
          softWrap: false,
        );
        final rtlCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          direction: TextDirection.rtl,
          textAlign: TextAlign.end,
          widthBasis: TextWidthBasis.longestLine,
          presetFontSizes: const <double>[30, 29],
          softWrap: false,
        );
        expect(<double>[
          ltrCandidate,
          rtlCandidate,
        ], orderedEquals(<double>[30, 29]));

        var paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          defaultAlign: TextAlign.end,
          defaultWidthBasis: TextWidthBasis.longestLine,
          child: SizedBox(
            width: width,
            height: 100,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 29],
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
        expect(paragraph.textDirection, TextDirection.rtl);
        expect(paragraph.textAlign, TextAlign.end);
        expect(paragraph.textWidthBasis, TextWidthBasis.longestLine);
        expect(paragraph.constraints.minWidth, width);
        expect(_rootSize(paragraph), rtlCandidate);
        final renderedRtlWitness = _measureWitness(
          text: text,
          style: style,
          constraints: constraints,
          direction: TextDirection.rtl,
          textAlign: TextAlign.end,
          widthBasis: TextWidthBasis.longestLine,
          candidate: rtlCandidate,
          softWrap: false,
        );
        expect(paragraph.textSize, renderedRtlWitness.size);
        expect(
          paragraph.didExceedMaxLines,
          renderedRtlWitness.didExceedMaxLines,
        );
        _expectPainterMatchesRenderParagraph(paragraph);

        paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          defaultWidthBasis: TextWidthBasis.longestLine,
          child: SizedBox(
            width: width,
            height: 100,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 29],
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
            ),
          ),
        );
        expect(paragraph.textDirection, TextDirection.ltr);
        expect(paragraph.textAlign, TextAlign.center);
        expect(_rootSize(paragraph), ltrCandidate);
      },
    );

    testWidgets(
      'should measure inherited and explicit locales with localized glyphs',
      (tester) async {
        const text = '٬٬٬٬٬٬';
        const style = TextStyle(
          inherit: false,
          fontFamily: _localeFixtureFamily,
          fontSize: 30,
        );
        const arabic = Locale('ar');
        const farsi = Locale('fa');
        final arabicWitness = _measureWitness(
          text: text,
          style: style,
          direction: TextDirection.rtl,
          locale: arabic,
        );
        final farsiWitness = _measureWitness(
          text: text,
          style: style,
          direction: TextDirection.rtl,
          locale: farsi,
        );
        final arabicWidth = arabicWitness.size.width;
        final farsiWidth = farsiWitness.size.width;
        expect(arabicWidth, isNot(closeTo(farsiWidth, 0.01)));
        expect(
          arabicWitness.lineWidth,
          isNot(closeTo(farsiWitness.lineWidth, 0.01)),
        );

        final farsiAt26 = _measureWitness(
          text: text,
          style: style,
          direction: TextDirection.rtl,
          locale: farsi,
          candidate: 26,
        ).size.width;
        final lowerThreshold = math.max(arabicWidth, farsiAt26);
        expect(lowerThreshold, lessThan(farsiWidth));
        final width = (lowerThreshold + farsiWidth) / 2;
        final constraints = BoxConstraints.tightFor(width: width, height: 100);
        final arabicCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          direction: TextDirection.rtl,
          locale: arabic,
          presetFontSizes: const <double>[30, 26],
          softWrap: false,
        );
        final farsiCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          direction: TextDirection.rtl,
          locale: farsi,
          presetFontSizes: const <double>[30, 26],
          softWrap: false,
        );
        expect(<double>[
          arabicCandidate,
          farsiCandidate,
        ], orderedEquals(<double>[30, 26]));

        var paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          locale: farsi,
          child: SizedBox(
            width: width,
            height: 100,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 26],
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
        expect(paragraph.locale, farsi);
        expect(_rootSize(paragraph), farsiCandidate);
        final renderedFarsiWitness = _measureWitness(
          text: text,
          style: style,
          constraints: constraints,
          direction: TextDirection.rtl,
          locale: farsi,
          candidate: farsiCandidate,
          softWrap: false,
        );
        expect(paragraph.textSize, renderedFarsiWitness.size);
        expect(
          paragraph.didExceedMaxLines,
          renderedFarsiWitness.didExceedMaxLines,
        );
        _expectPainterMatchesRenderParagraph(paragraph);

        paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          locale: farsi,
          child: SizedBox(
            width: width,
            height: 100,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 26],
              maxLines: 1,
              softWrap: false,
              locale: arabic,
            ),
          ),
        );
        expect(paragraph.locale, arabic);
        expect(_rootSize(paragraph), arabicCandidate);

        paragraph = await _pumpParagraph(
          tester,
          direction: TextDirection.rtl,
          locale: arabic,
          child: SizedBox(
            width: width,
            height: 100,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 26],
              maxLines: 1,
              softWrap: false,
              locale: farsi,
            ),
          ),
        );
        expect(paragraph.locale, farsi);
        expect(_rootSize(paragraph), farsiCandidate);
      },
    );

    testWidgets(
      'should measure default and ambient text height behavior metrics',
      (tester) async {
        const text = 'Hg';
        const style = TextStyle(
          inherit: false,
          fontFamily: _robotoFixtureFamily,
          fontSize: 30,
          height: 3,
        );
        const normalBehavior = TextHeightBehavior();
        const compactBehavior = TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        );
        final normalWitness = _measureWitness(
          text: text,
          style: style,
          heightBehavior: normalBehavior,
        );
        final compactWitness = _measureWitness(
          text: text,
          style: style,
          heightBehavior: compactBehavior,
        );
        expect(
          normalWitness.size.height,
          isNot(closeTo(compactWitness.size.height, 0.01)),
        );
        expect(
          normalWitness.baseline,
          isNot(closeTo(compactWitness.baseline, 0.01)),
        );
        expect(normalWitness.size.height, closeTo(90, 0.01));
        expect(compactWitness.size.height, closeTo(35, 0.01));

        const height = 60.0;
        final constraints = BoxConstraints.tightFor(width: 300, height: height);
        final normalCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          heightBehavior: normalBehavior,
          presetFontSizes: const <double>[30, 20],
        );
        final compactCandidate = _largestWitnessCandidate(
          text: text,
          style: style,
          constraints: constraints,
          heightBehavior: compactBehavior,
          presetFontSizes: const <double>[30, 20],
        );
        expect(<double>[
          normalCandidate,
          compactCandidate,
        ], orderedEquals(<double>[20, 30]));

        var paragraph = await _pumpParagraph(
          tester,
          defaultHeightBehavior: compactBehavior,
          ambientHeightBehavior: normalBehavior,
          child: SizedBox(
            width: 300,
            height: height,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 20],
              maxLines: 1,
            ),
          ),
        );
        final renderedWitness = _measureWitness(
          text: text,
          style: style,
          constraints: constraints,
          heightBehavior: compactBehavior,
          candidate: compactCandidate,
        );
        expect(paragraph.textHeightBehavior, compactBehavior);
        expect(_rootSize(paragraph), compactCandidate);
        expect(paragraph.textSize, renderedWitness.size);
        expect(paragraph.didExceedMaxLines, renderedWitness.didExceedMaxLines);
        expect(
          paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!,
          closeTo(renderedWitness.baseline, 0.01),
        );

        paragraph = await _pumpParagraph(
          tester,
          defaultHeightBehavior: null,
          ambientHeightBehavior: compactBehavior,
          child: SizedBox(
            width: 300,
            height: height,
            child: const AutoSizeText(
              text,
              style: style,
              presetFontSizes: <double>[30, 20],
              maxLines: 1,
            ),
          ),
        );
        expect(paragraph.textHeightBehavior, compactBehavior);
        expect(_rootSize(paragraph), compactCandidate);
        _expectPainterMatchesRenderParagraph(
          paragraph,
          referenceFontSize: 30,
          minFontSize: 10,
        );
      },
    );
  });
}

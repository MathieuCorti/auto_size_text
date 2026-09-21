import 'dart:collection';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

final class _OracleTextScaler extends TextScaler {
  const _OracleTextScaler();

  @override
  double scale(double fontSize) => fontSize + fontSize * fontSize / 100;

  @override
  double get textScaleFactor => 99;
}

final class _UnknownTextSpan extends TextSpan {
  const _UnknownTextSpan({super.text, super.style});
}

Future<RenderParagraph> _pumpParagraph(
  WidgetTester tester, {
  required Widget child,
  MediaQueryData mediaQueryData = const MediaQueryData(),
  TextStyle defaultStyle = const TextStyle(fontFamily: 'Ahem', fontSize: 20),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: mediaQueryData.copyWith(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: defaultStyle,
          child: Center(child: child),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

double _rootSize(RenderParagraph paragraph) {
  final rootSize = paragraph.text.style!.fontSize!;
  return paragraph.textScaler.scale(rootSize);
}

double _selectionWidth(RenderParagraph paragraph, int start, int end) =>
    paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        )
        .fold<double>(0, (width, box) => width + (box.right - box.left).abs());

SemanticsNode? _findSemanticsNode(SemanticsNode node, String label) {
  if (node.label == label) {
    return node;
  }
  SemanticsNode? result;
  node.visitChildren((child) {
    result = _findSemanticsNode(child, label);
    return result == null;
  });
  return result;
}

void _expectPainterMatchesRenderParagraph(RenderParagraph paragraph) {
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
      minWidth: paragraph.constraints.minWidth,
      maxWidth:
          paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
          ? paragraph.constraints.maxWidth
          : double.infinity,
    );
    expect(painter.size, paragraph.textSize);
    expect(painter.didExceedMaxLines, paragraph.didExceedMaxLines);
    expect(paragraph.size, paragraph.constraints.constrain(painter.size));
    expect(
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic),
    );
  } finally {
    painter.dispose();
  }
}

void main() {
  group('AutoSizeText rich text', () {
    testWidgets(
      'should inherit the effective parent through a partially styled root',
      (tester) async {
        const source = TextSpan(
          text: 'AAAA',
          style: TextStyle(color: Colors.red),
        );

        final paragraph = await _pumpParagraph(
          tester,
          defaultStyle: const TextStyle(
            fontFamily: 'Ahem',
            fontSize: 30,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          child: const SizedBox(
            width: 100,
            height: 100,
            child: AutoSizeText.rich(
              source,
              presetFontSizes: <double>[30, 20],
              maxLines: 1,
              textScaler: TextScaler.noScaling,
            ),
          ),
        );

        expect(_rootSize(paragraph), 20);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          _selectionWidth(paragraph, 0, 4),
          closeTo(80, selectionWidthTolerance),
        );
        _expectPainterMatchesRenderParagraph(paragraph);
        final renderedSource =
            (paragraph.text as TextSpan).children!.single as TextSpan;
        expect(renderedSource.style!.color, Colors.red);
        expect(renderedSource.style!.fontSize, isNull);
        expect(identical(renderedSource, source), isTrue);
      },
    );

    testWidgets(
      'should scale every nested run before a nonlinear user scaler',
      (tester) async {
        const source = TextSpan(
          text: 'A',
          children: <InlineSpan>[
            TextSpan(
              text: 'B',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                height: 1.4,
                letterSpacing: 2,
                wordSpacing: 3,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: 'C',
                  style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
                ),
              ],
            ),
          ],
        );

        final paragraph = await _pumpParagraph(
          tester,
          child: const SizedBox(
            width: 200,
            height: 100,
            child: AutoSizeText.rich(
              source,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              presetFontSizes: <double>[10],
              textScaler: _OracleTextScaler(),
              maxLines: 1,
            ),
          ),
        );

        expect(_rootSize(paragraph), 11);
        expect(paragraph.textScaler.scale(40), 24);
        expect(
          _selectionWidth(paragraph, 0, 1),
          closeTo(11, selectionWidthTolerance),
        );
        expect(
          _selectionWidth(paragraph, 1, 2),
          closeTo(26, selectionWidthTolerance),
        );
        expect(
          _selectionWidth(paragraph, 2, 3),
          closeTo(13, selectionWidthTolerance),
        );
        _expectPainterMatchesRenderParagraph(paragraph);
      },
    );

    testWidgets(
      'should apply spacing overrides once to measurement and rendering',
      (tester) async {
        const textKey = ValueKey<String>('rich-spacing');
        const source = TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'AAAA',
              style: TextStyle(
                fontSize: 20,
                height: 2,
                letterSpacing: 0,
                wordSpacing: 0,
              ),
            ),
          ],
        );

        final paragraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(
            lineHeightScaleFactorOverride: 1.25,
            letterSpacingOverride: 10,
            wordSpacingOverride: 7,
          ),
          child: const SizedBox(
            width: 100,
            height: 100,
            child: AutoSizeText.rich(
              source,
              textKey: textKey,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
              presetFontSizes: <double>[20, 10],
              textScaler: TextScaler.noScaling,
              maxLines: 1,
            ),
          ),
        );

        expect(_rootSize(paragraph), 10);
        final text = textWidgetForKey(tester, textKey);
        expect(identical(text.textSpan, source), isTrue);
        expect(text.style, const TextStyle(fontFamily: 'Ahem', fontSize: 20));
        final renderedSource =
            (paragraph.text as TextSpan).children!.single as TextSpan;
        final renderedChild = renderedSource.children!.single as TextSpan;
        expect(renderedChild.style!.height, 1.25);
        expect(renderedChild.style!.letterSpacing, 10);
        expect(renderedChild.style!.wordSpacing, 7);
        expect(
          _selectionWidth(paragraph, 0, 4),
          closeTo(80, selectionWidthTolerance),
        );
        _expectPainterMatchesRenderParagraph(paragraph);
      },
    );

    testWidgets(
      'should clone only standard spans and preserve every metadata object',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        final recognizer = TapGestureRecognizer();
        var taps = 0;
        var enters = 0;
        var exits = 0;
        recognizer.onTap = () => taps += 1;
        final unknown = const _UnknownTextSpan(
          text: 'U',
          style: TextStyle(fontSize: 20),
        );
        final children = UnmodifiableListView<InlineSpan>(<InlineSpan>[
          unknown,
        ]);
        final source = TextSpan(
          text: 'tap',
          style: const TextStyle(color: Colors.blue),
          children: children,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
          onEnter: (_) => enters += 1,
          onExit: (_) => exits += 1,
          semanticsLabel: 'spoken',
          semanticsIdentifier: 'rich-span',
          locale: const Locale('en', 'GB'),
          spellOut: true,
        );

        final paragraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(letterSpacingOverride: 1),
          child: SizedBox(
            width: 200,
            height: 100,
            child: AutoSizeText.rich(
              source,
              style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
              textScaler: TextScaler.noScaling,
            ),
          ),
        );

        final renderedRoot = paragraph.text as TextSpan;
        final clone = renderedRoot.children!.single as TextSpan;
        expect(identical(clone, source), isFalse);
        expect(identical(clone.children, children), isFalse);
        expect(identical(clone.children!.single, unknown), isTrue);
        expect(identical(clone.recognizer, recognizer), isTrue);
        expect(clone.mouseCursor, same(SystemMouseCursors.click));
        expect(clone.onEnter, same(source.onEnter));
        expect(clone.onExit, same(source.onExit));
        expect(clone.semanticsLabel, 'spoken');
        expect(clone.semanticsIdentifier, 'rich-span');
        expect(clone.locale, const Locale('en', 'GB'));
        expect(clone.spellOut, isTrue);
        expect(identical(source.children, children), isTrue);
        expect(source.style, const TextStyle(color: Colors.blue));

        final richText = find.byType(RichText);
        final paragraphOrigin = tester.getTopLeft(richText);
        final tapBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 3),
            )
            .first;
        final target =
            paragraphOrigin +
            Rect.fromLTRB(
              tapBox.left,
              tapBox.top,
              tapBox.right,
              tapBox.bottom,
            ).center;
        await tester.tapAt(target);
        expect(taps, 1);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(target);
        await tester.pump();
        expect(enters, 1);
        expect(
          tester.binding.mouseTracker.debugDeviceActiveCursor(1),
          same(SystemMouseCursors.click),
        );
        await mouse.moveTo(
          tester.getBottomRight(richText) + const Offset(20, 20),
        );
        await tester.pump();
        expect(exits, 1);
        await mouse.removePointer();

        final semanticsRoot = paragraph.debugSemantics!;
        final semantics = _findSemanticsNode(semanticsRoot, 'spoken')!;
        expect(semantics.label, 'spoken');
        expect(semantics.getSemanticsData().identifier, 'rich-span');
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );

        final rebuiltParagraph = await _pumpParagraph(
          tester,
          mediaQueryData: const MediaQueryData(wordSpacingOverride: 2),
          child: SizedBox(
            width: 200,
            height: 100,
            child: AutoSizeText.rich(
              source,
              style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
              textScaler: TextScaler.noScaling,
            ),
          ),
        );
        final rebuiltClone =
            (rebuiltParagraph.text as TextSpan).children!.single as TextSpan;
        expect(identical(rebuiltClone.recognizer, recognizer), isTrue);
        expect(rebuiltClone.semanticsIdentifier, 'rich-span');
        expect(identical(source.children, children), isTrue);

        final rebuiltOrigin = tester.getTopLeft(find.byType(RichText));
        final rebuiltTapBox = rebuiltParagraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 3),
            )
            .first;
        await tester.tapAt(
          rebuiltOrigin +
              Rect.fromLTRB(
                rebuiltTapBox.left,
                rebuiltTapBox.top,
                rebuiltTapBox.right,
                rebuiltTapBox.bottom,
              ).center,
        );
        expect(taps, 2);
        final rebuiltSemantics = _findSemanticsNode(
          rebuiltParagraph.debugSemantics!,
          'spoken',
        )!;
        expect(rebuiltSemantics.getSemanticsData().identifier, 'rich-span');

        await tester.pumpWidget(const SizedBox.shrink());
        recognizer.dispose();
        semanticsHandle.dispose();
      },
    );

    testWidgets(
      'should keep the source tree immutable across override rebuilds',
      (tester) async {
        final nestedChildren = UnmodifiableListView<InlineSpan>(
          const <InlineSpan>[TextSpan(text: 'nested')],
        );
        final nested = TextSpan(
          text: 'child',
          style: const TextStyle(fontSize: 30),
          children: nestedChildren,
        );
        final rootChildren = UnmodifiableListView<InlineSpan>(<InlineSpan>[
          nested,
        ]);
        final source = TextSpan(
          text: 'root',
          style: const TextStyle(color: Colors.green),
          children: rootChildren,
        );

        Future<TextSpan> pumpWith(MediaQueryData data) async {
          final paragraph = await _pumpParagraph(
            tester,
            mediaQueryData: data,
            child: AutoSizeText.rich(
              source,
              style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
              textScaler: TextScaler.noScaling,
            ),
          );
          return (paragraph.text as TextSpan).children!.single as TextSpan;
        }

        final withoutOverride = await pumpWith(const MediaQueryData());
        expect(identical(withoutOverride, source), isTrue);
        final withHeight = await pumpWith(
          const MediaQueryData(lineHeightScaleFactorOverride: 1.5),
        );
        expect(identical(withHeight, source), isFalse);
        final withSpacing = await pumpWith(
          const MediaQueryData(
            letterSpacingOverride: 2,
            wordSpacingOverride: 3,
          ),
        );
        expect(identical(withSpacing, source), isFalse);
        final restored = await pumpWith(const MediaQueryData());
        expect(identical(restored, source), isTrue);

        expect(identical(source.children, rootChildren), isTrue);
        expect(identical(source.children!.single, nested), isTrue);
        expect(identical(nested.children, nestedChildren), isTrue);
        expect(source.style, const TextStyle(color: Colors.green));
        expect(nested.style, const TextStyle(fontSize: 30));
      },
    );

    testWidgets(
      'should prioritize the widget semantics label over span labels',
      (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        await _pumpParagraph(
          tester,
          child: const AutoSizeText.rich(
            TextSpan(text: 'visual', semanticsLabel: 'span label'),
            style: TextStyle(fontFamily: 'Ahem', fontSize: 20),
            textScaler: TextScaler.noScaling,
            semanticsLabel: 'widget label',
          ),
        );

        final semanticsRoot = tester.getSemantics(find.byType(Text));
        expect(_findSemanticsNode(semanticsRoot, 'widget label'), isNotNull);
        expect(_findSemanticsNode(semanticsRoot, 'span label'), isNull);
        semanticsHandle.dispose();
      },
    );

    testWidgets('should use the candidate as the zero-reference parent size', (
      tester,
    ) async {
      const textKey = ValueKey<String>('zero-rich');
      const source = TextSpan(
        text: 'A',
        children: <InlineSpan>[
          TextSpan(text: 'B', style: TextStyle(fontSize: 20)),
          TextSpan(text: 'C', style: TextStyle(fontSize: 0)),
        ],
      );

      final paragraph = await _pumpParagraph(
        tester,
        child: const SizedBox(
          width: 100,
          height: 100,
          child: AutoSizeText.rich(
            source,
            textKey: textKey,
            style: TextStyle(fontFamily: 'Ahem', fontSize: 0),
            minFontSize: 10,
            maxFontSize: 20,
            textScaler: _OracleTextScaler(),
            maxLines: 1,
          ),
        ),
      );

      expect(textWidgetForKey(tester, textKey), isA<Text>());
      expect(paragraph.text.style!.fontSize, 10);
      expect(
        identical(paragraph.textScaler, const _OracleTextScaler()),
        isTrue,
      );
      expect(_rootSize(paragraph), 11);
      expect(
        _selectionWidth(paragraph, 0, 1),
        closeTo(11, selectionWidthTolerance),
      );
      expect(
        _selectionWidth(paragraph, 1, 2),
        closeTo(24, selectionWidthTolerance),
      );
      expect(_selectionWidth(paragraph, 2, 3), 0);
      _expectPainterMatchesRenderParagraph(paragraph);
    });

    testWidgets(
      'should render simple and rich zero references at a zero minimum',
      (tester) async {
        const simpleKey = ValueKey<String>('zero-simple');
        var paragraph = await _pumpParagraph(
          tester,
          child: const SizedBox(
            width: 100,
            height: 100,
            child: AutoSizeText(
              'A',
              textKey: simpleKey,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 0),
              minFontSize: 0,
              textScaler: _OracleTextScaler(),
            ),
          ),
        );
        expect(textWidgetForKey(tester, simpleKey), isA<Text>());
        expect(paragraph.text.style!.fontSize, 0);
        expect(_rootSize(paragraph), 0);
        expect(paragraph.textSize.isFinite, isTrue);

        const richKey = ValueKey<String>('zero-rich-minimum');
        paragraph = await _pumpParagraph(
          tester,
          child: const SizedBox(
            width: 100,
            height: 100,
            child: AutoSizeText.rich(
              TextSpan(
                text: 'A',
                children: <InlineSpan>[
                  TextSpan(text: 'B', style: TextStyle(fontSize: 20)),
                ],
              ),
              textKey: richKey,
              style: TextStyle(fontFamily: 'Ahem', fontSize: 0),
              minFontSize: 0,
              textScaler: _OracleTextScaler(),
            ),
          ),
        );
        expect(textWidgetForKey(tester, richKey), isA<Text>());
        expect(paragraph.text.style!.fontSize, 0);
        expect(_rootSize(paragraph), 0);
        expect(_selectionWidth(paragraph, 0, 1), 0);
        expect(
          _selectionWidth(paragraph, 1, 2),
          closeTo(24, selectionWidthTolerance),
        );
      },
    );

    testWidgets(
      'should replace zero-reference text only when its real runs do not fit',
      (tester) async {
        const simpleKey = ValueKey<String>('zero-simple-overflow');
        const replacementKey = ValueKey<String>('zero-replacement');
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 5,
                height: 5,
                child: AutoSizeText(
                  'AA',
                  textKey: simpleKey,
                  style: TextStyle(fontFamily: 'Ahem', fontSize: 0),
                  minFontSize: 10,
                  maxFontSize: 20,
                  textScaler: _OracleTextScaler(),
                  maxLines: 1,
                  softWrap: false,
                  overflowReplacement: SizedBox(key: replacementKey),
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(replacementKey), findsOneWidget);
        expect(find.byKey(simpleKey), findsNothing);

        const richKey = ValueKey<String>('zero-rich-overflow');
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 5,
                height: 5,
                child: AutoSizeText.rich(
                  TextSpan(
                    text: 'A',
                    children: <InlineSpan>[
                      TextSpan(text: 'B', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                  textKey: richKey,
                  style: TextStyle(fontFamily: 'Ahem', fontSize: 0),
                  minFontSize: 0,
                  textScaler: _OracleTextScaler(),
                  maxLines: 1,
                  softWrap: false,
                  overflowReplacement: SizedBox(key: replacementKey),
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(replacementKey), findsOneWidget);
        expect(find.byKey(richKey), findsNothing);
      },
    );

    testWidgets(
      'should support WidgetSpan without cloning its source widget span',
      (tester) async {
        final textKey = GlobalKey();
        const widgetSpan = WidgetSpan(child: SizedBox(width: 10, height: 10));
        const source = TextSpan(children: <InlineSpan>[widgetSpan]);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(letterSpacingOverride: 2),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AutoSizeText.rich(
                source,
                textKey: textKey,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );

        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(textKey),
        );
        final renderedSource = (paragraph.text as TextSpan).children!.single;
        expect(
          identical((renderedSource as TextSpan).children!.single, widgetSpan),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        expect(identical(source.children!.single, widgetSpan), isTrue);
      },
    );
  });
}

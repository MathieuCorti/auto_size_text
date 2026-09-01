import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuadraticTextScaler extends TextScaler {
  const _QuadraticTextScaler();

  @override
  double scale(double fontSize) => fontSize * fontSize / 10;

  @override
  double get textScaleFactor => 99;
}

class _InvalidTextScaler extends TextScaler {
  const _InvalidTextScaler(this.result, {this.invalidAbove});

  final double result;
  final double? invalidAbove;

  @override
  double scale(double fontSize) {
    if (invalidAbove == null || fontSize > invalidAbove!) {
      return result;
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

class _ConflictingAutoSizeText extends AutoSizeText {
  const _ConflictingAutoSizeText() : super('conflicting');

  @override
  TextScaler get textScaler => TextScaler.noScaling;

  @override
  // ignore: deprecated_member_use_from_same_package
  double get textScaleFactor => 1;
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  TextScaler ambientScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: ambientScaler),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    ),
  );
}

Future<RenderParagraph> _pumpParagraph(
  WidgetTester tester, {
  required Widget child,
  TextScaler ambientScaler = TextScaler.noScaling,
}) async {
  await _pump(tester, child: child, ambientScaler: ambientScaler);
  return tester.renderObject<RenderParagraph>(find.byType(RichText));
}

double _renderedRootSize(RenderParagraph paragraph) {
  final rootSize = paragraph.text.style!.fontSize!;
  return paragraph.textScaler.scale(rootSize);
}

void main() {
  group('AutoSizeText TextScaler', () {
    test('should keep both constructors const with a modern scaler', () {
      const simple = AutoSizeText('simple', textScaler: TextScaler.noScaling);
      const rich = AutoSizeText.rich(
        TextSpan(text: 'rich'),
        textScaler: TextScaler.noScaling,
      );

      expect(simple.textScaler, TextScaler.noScaling);
      expect(rich.textScaler, TextScaler.noScaling);
    });

    test('should assert mutual exclusion in both const constructors', () {
      expect(
        () => AutoSizeText(
          'simple',
          textScaler: TextScaler.noScaling,
          // ignore: deprecated_member_use_from_same_package
          textScaleFactor: 1,
        ),
        throwsAssertionError,
      );
      expect(
        () => AutoSizeText.rich(
          const TextSpan(text: 'rich'),
          textScaler: TextScaler.noScaling,
          // ignore: deprecated_member_use_from_same_package
          textScaleFactor: 1,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('should reject mutual exclusion in the runtime resolver', (
      tester,
    ) async {
      await _pump(tester, child: const _ConflictingAutoSizeText());
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets(
      'should prioritize explicit, legacy, and ambient scalers without '
      'reading the compatibility getter',
      (tester) async {
        var paragraph = await _pumpParagraph(
          tester,
          ambientScaler: const _QuadraticTextScaler(),
          child: const AutoSizeText('', style: TextStyle(fontSize: 20)),
        );
        expect(_renderedRootSize(paragraph), 40);

        paragraph = await _pumpParagraph(
          tester,
          ambientScaler: const _QuadraticTextScaler(),
          child: const AutoSizeText(
            '',
            style: TextStyle(fontSize: 20),
            textScaler: TextScaler.noScaling,
          ),
        );
        expect(_renderedRootSize(paragraph), 20);

        paragraph = await _pumpParagraph(
          tester,
          child: const AutoSizeText(
            '',
            style: TextStyle(fontSize: 20),
            textScaler: TextScaler.linear(1.5),
          ),
        );
        expect(_renderedRootSize(paragraph), 30);

        paragraph = await _pumpParagraph(
          tester,
          ambientScaler: const _QuadraticTextScaler(),
          child: const AutoSizeText(
            '',
            style: TextStyle(fontSize: 20),
            // ignore: deprecated_member_use_from_same_package
            textScaleFactor: 2,
          ),
        );
        expect(_renderedRootSize(paragraph), 40);
      },
    );

    testWidgets('should compose a nonlinear scaler before the user curve', (
      tester,
    ) async {
      final paragraph = await _pumpParagraph(
        tester,
        child: const SizedBox(
          width: 250,
          height: 100,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 30),
            presetFontSizes: <double>[30, 20, 10],
            textScaler: _QuadraticTextScaler(),
            maxLines: 1,
          ),
        ),
      );

      expect(_renderedRootSize(paragraph), 40);
      expect(paragraph.textSize.width, 250);
    });

    testWidgets('should reject every invalid custom scaler result', (
      tester,
    ) async {
      for (final invalid in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1,
      ]) {
        await _pump(
          tester,
          child: AutoSizeText(
            'invalid',
            key: UniqueKey(),
            style: const TextStyle(fontSize: 20),
            textScaler: _InvalidTextScaler(invalid),
          ),
        );
        expect(tester.takeException(), isA<ArgumentError>());
      }
    });

    testWidgets(
      'should validate custom scaler results reached only by the strut',
      (tester) async {
        await _pump(
          tester,
          child: const AutoSizeText(
            'strut',
            style: TextStyle(fontSize: 20),
            strutStyle: StrutStyle(fontSize: 100, forceStrutHeight: true),
            textScaler: _InvalidTextScaler(double.infinity, invalidAbove: 50),
          ),
        );

        expect(tester.takeException(), isA<ArgumentError>());
      },
    );

    testWidgets(
      'should rebuild the composed scaler when inherited scaling changes',
      (tester) async {
        final child = const AutoSizeText('', style: TextStyle(fontSize: 20));
        final first = await _pumpParagraph(
          tester,
          child: child,
          ambientScaler: TextScaler.noScaling,
        );
        final firstScaler = first.textScaler;
        expect(_renderedRootSize(first), 20);

        final second = await _pumpParagraph(
          tester,
          child: child,
          ambientScaler: const _QuadraticTextScaler(),
        );
        expect(_renderedRootSize(second), 40);
        expect(second.textScaler, isNot(firstScaler));

        final third = await _pumpParagraph(
          tester,
          child: child,
          ambientScaler: const _QuadraticTextScaler(),
        );
        expect(third.textScaler, second.textScaler);
        expect(third.textScaler.hashCode, second.textScaler.hashCode);
      },
    );

    testWidgets('should preserve homogeneous groups with linear scaling', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      await _pump(
        tester,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 160,
              height: 80,
              child: AutoSizeText(
                'XXXXX',
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 30),
                minFontSize: 10,
                maxLines: 1,
                textScaler: const TextScaler.linear(2),
                group: group,
              ),
            ),
            SizedBox(
              width: 240,
              height: 80,
              child: AutoSizeText(
                'XXXXX',
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 30),
                minFontSize: 10,
                maxLines: 1,
                textScaler: const TextScaler.linear(2),
                group: group,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      final paragraphs = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .toList();
      expect(paragraphs, hasLength(2));
      expect(_renderedRootSize(paragraphs[0]), 32);
      expect(_renderedRootSize(paragraphs[1]), 32);
    });
  });
}

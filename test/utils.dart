import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Engine selection boxes cross the dart:ui boundary as Float32List values.
// These Linux Ahem fixtures measured up to 0.0000763 logical px away from their
// ideal advances on both supported SDKs. Keep this local to rendered geometry:
// candidate font sizes, scaler outputs, and zero-width runs stay exact.
const selectionWidthTolerance = 0.0001;

double effectiveFontSize(Widget widget) {
  final text = widget is Text ? widget : (widget as dynamic).child as Text;
  return (text.textScaler ?? TextScaler.noScaling).scale(text.style!.fontSize!);
}

Text textWidgetForKey(WidgetTester tester, Key key) {
  return tester.widget<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  );
}

RenderParagraph renderParagraphForKey(WidgetTester tester, Key key) {
  return tester.renderObject<RenderParagraph>(find.byKey(key));
}

double effectiveFontSizeForKey(WidgetTester tester, Key key) {
  final paragraph = renderParagraphForKey(tester, key);
  return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
}

bool renderParagraphFits(RenderParagraph paragraph, {bool wrapWords = true}) {
  final constraints = paragraph.constraints;

  if (!wrapWords) {
    final unwrappedPainter = _resolvedTextPainter(paragraph);
    try {
      unwrappedPainter.layout(maxWidth: double.infinity);
      final plainText = paragraph.text.toPlainText(
        includeSemanticsLabels: false,
      );
      for (final match in _indivisibleTextRuns.allMatches(plainText)) {
        final boxes = unwrappedPainter.getBoxesForSelection(
          TextSelection(baseOffset: match.start, extentOffset: match.end),
        );
        final width = boxes.fold<double>(
          0,
          (sum, box) => sum + (box.right - box.left).abs(),
        );
        if (width > constraints.maxWidth) {
          return false;
        }
      }
    } finally {
      unwrappedPainter.dispose();
    }
  }

  final painter = _resolvedTextPainter(paragraph, maxLines: paragraph.maxLines);
  try {
    final layoutMaxWidth =
        paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
        ? constraints.maxWidth
        : double.infinity;
    painter.layout(minWidth: constraints.minWidth, maxWidth: layoutMaxWidth);
    final textSize = painter.size;
    final renderSize = constraints.constrain(textSize);

    return !painter.didExceedMaxLines &&
        renderSize.width >= textSize.width &&
        renderSize.height >= textSize.height;
  } finally {
    painter.dispose();
  }
}

final RegExp _indivisibleTextRuns = RegExp(r'(?:[^\s]|[\u00A0\u202F])+');

TextPainter _resolvedTextPainter(RenderParagraph paragraph, {int? maxLines}) =>
    TextPainter(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    );

bool prepared = false;

Future<void> prepareTests(WidgetTester tester) async {
  if (prepared) {
    return;
  }

  prepared = true;
  final fontData = File('test/assets/Roboto-Regular.ttf').readAsBytes().then(
    (bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
  );

  final fontLoader = FontLoader('Roboto')..addFont(fontData);
  await fontLoader.load();
}

Future<void> pump({
  required WidgetTester tester,
  required Widget widget,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: widget),
    ),
  );
}

Future<Text> pumpAndGetText({
  required WidgetTester tester,
  required Widget widget,
}) async {
  await pump(tester: tester, widget: widget);
  return tester.widget<Text>(find.byType(Text));
}

Future<void> pumpAndExpectFontSize({
  required WidgetTester tester,
  required double expectedFontSize,
  required Widget widget,
}) async {
  await pump(tester: tester, widget: widget);
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
  final rootFontSize = paragraph.text.style!.fontSize!;
  expect(paragraph.textScaler.scale(rootFontSize), expectedFontSize);
}

RichText getRichText(WidgetTester tester) =>
    tester.widget(find.byType(RichText));

class OverflowNotifier extends StatelessWidget {
  const OverflowNotifier(this.overflowCallback, {super.key});

  final VoidCallback overflowCallback;

  @override
  Widget build(BuildContext context) {
    overflowCallback();
    return Container();
  }
}

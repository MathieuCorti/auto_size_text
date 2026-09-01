import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double effectiveFontSize(Text text) =>
    (text.textScaler ?? TextScaler.noScaling).scale(text.style!.fontSize!);

bool doesTextFit(
  Text text, [
  double maxWidth = double.infinity,
  double maxHeight = double.infinity,
  bool wrapWords = true,
]) {
  final span = text.textSpan ?? TextSpan(text: text.data, style: text.style);
  var maxLines = text.maxLines;
  if (!wrapWords && maxLines != null) {
    final wordCount = span.toPlainText().split(RegExp('\\s+')).length;
    maxLines = maxLines.clamp(1, wordCount);
  }

  final textPainter = TextPainter(
    text: span,
    textAlign: text.textAlign ?? TextAlign.start,
    textDirection: text.textDirection,
    textScaler: text.textScaler ?? TextScaler.noScaling,
    maxLines: maxLines,
    locale: text.locale,
    strutStyle: text.strutStyle,
  );

  try {
    textPainter.layout(maxWidth: maxWidth);

    return !(textPainter.didExceedMaxLines ||
        textPainter.height > maxHeight ||
        textPainter.width > maxWidth);
  } finally {
    textPainter.dispose();
  }
}

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

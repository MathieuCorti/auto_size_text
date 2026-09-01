import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'leak_tracking.dart';
import 'utils.dart';

class _ThrowingTextSpan extends TextSpan {
  const _ThrowingTextSpan();

  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    throw StateError('intentional layout failure');
  }
}

void main() {
  group('AutoSizeText TextPainter lifecycle', () {
    testWidgets('should dispose the helper painter after checking text fit', (
      _,
    ) async {
      const text = Text(
        'helper text',
        style: TextStyle(fontSize: 20),
        textDirection: TextDirection.ltr,
      );

      expect(doesTextFit(text, 200, 40), isTrue);
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets('should dispose the painter when the initial font size fits', (
      tester,
    ) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: const AutoSizeText('fits', style: TextStyle(fontSize: 20)),
      );

      expect(effectiveFontSize(text), 20);
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets('should dispose every painter when no font size fits', (
      tester,
    ) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: const SizedBox(
          width: 1,
          height: 1,
          child: AutoSizeText(
            'does not fit',
            style: TextStyle(fontSize: 20),
            minFontSize: 10,
            maxFontSize: 20,
            overflowReplacement: Text('overflow'),
          ),
        ),
      );

      expect(text.data, 'overflow');
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets('should dispose the word painter before an early return', (
      tester,
    ) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: const SizedBox(
          width: 1,
          child: AutoSizeText(
            'unbreakable',
            style: TextStyle(fontSize: 20),
            minFontSize: 10,
            maxFontSize: 20,
            wrapWords: false,
            overflowReplacement: Text('overflow'),
          ),
        ),
      );

      expect(text.data, 'overflow');
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets(
      'should dispose both painters when wrapWords is false and text fits',
      (tester) async {
        final text = await pumpAndGetText(
          tester: tester,
          widget: const SizedBox(
            width: 200,
            child: AutoSizeText(
              'short words',
              style: TextStyle(fontSize: 20),
              wrapWords: false,
            ),
          ),
        );

        expect(effectiveFontSize(text), 20);
      },
      experimentalLeakTesting: nativeResourceLeakTesting,
    );

    testWidgets('should dispose the painter when paragraph layout throws', (
      tester,
    ) async {
      await pump(
        tester: tester,
        widget: const AutoSizeText.rich(
          TextSpan(children: <InlineSpan>[_ThrowingTextSpan()]),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets('should dispose painters across repeated rebuilds', (
      tester,
    ) async {
      late StateSetter rebuild;
      var fontSize = 20.0;

      await pump(
        tester: tester,
        widget: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AutoSizeText(
              'rebuild',
              style: TextStyle(fontSize: fontSize),
            );
          },
        ),
      );

      for (final nextFontSize in <double>[19, 18, 17, 16]) {
        rebuild(() => fontSize = nextFontSize);
        await tester.pump();
      }

      final text = tester.widget<Text>(find.byType(Text));
      expect(effectiveFontSize(text), 16);
    }, experimentalLeakTesting: nativeResourceLeakTesting);

    testWidgets(
      'should dispose painters when a member is removed from its group',
      (tester) async {
        final group = AutoSizeGroup();
        late StateSetter removeMember;
        var showSecondMember = true;

        await pump(
          tester: tester,
          widget: StatefulBuilder(
            builder: (context, setState) {
              removeMember = setState;
              return Column(
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    child: AutoSizeText(
                      'first',
                      style: const TextStyle(fontSize: 20),
                      group: group,
                    ),
                  ),
                  if (showSecondMember)
                    SizedBox(
                      width: 100,
                      child: AutoSizeText(
                        'second member',
                        style: const TextStyle(fontSize: 20),
                        group: group,
                      ),
                    ),
                ],
              );
            },
          ),
        );

        removeMember(() => showSecondMember = false);
        await tester.pump();
        await tester.pump();

        expect(find.text('first'), findsOneWidget);
        expect(find.text('second member'), findsNothing);
      },
      experimentalLeakTesting: nativeResourceLeakTesting,
    );
  });
}

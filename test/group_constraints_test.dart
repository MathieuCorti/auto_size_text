import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final class _QuadraticTextScaler extends TextScaler {
  const _QuadraticTextScaler();

  @override
  double scale(double fontSize) => fontSize * fontSize / 10;

  @override
  double get textScaleFactor => 99;
}

final class _MappedTextScaler extends TextScaler {
  const _MappedTextScaler({required this.upperResult});

  final double upperResult;

  @override
  double scale(double fontSize) {
    if (fontSize >= 30) {
      return upperResult;
    }
    if (fontSize >= 20) {
      return 10;
    }
    return 5;
  }

  @override
  double get textScaleFactor => 99;
}

final class _CappedTextScaler extends TextScaler {
  const _CappedTextScaler();

  @override
  double scale(double fontSize) => fontSize.clamp(0, 20).toDouble();

  @override
  double get textScaleFactor => 99;
}

final class _ZeroRootPlateauTextScaler extends TextScaler {
  const _ZeroRootPlateauTextScaler();

  @override
  double scale(double fontSize) => fontSize <= 30 ? 0 : fontSize - 30;

  @override
  double get textScaleFactor => 99;
}

final class _ScaleCounter {
  int calls = 0;
}

final class _CountingIdentityTextScaler extends TextScaler {
  const _CountingIdentityTextScaler(this.counter);

  final _ScaleCounter counter;

  @override
  double scale(double fontSize) {
    counter.calls += 1;
    return fontSize;
  }

  @override
  double get textScaleFactor => 99;
}

final class _ProjectionInvalidTextScaler extends TextScaler {
  const _ProjectionInvalidTextScaler();

  @override
  double scale(double fontSize) => fontSize == 20 ? double.nan : fontSize;

  @override
  double get textScaleFactor => 99;
}

final class _GroupMicrotaskCounts {
  int scheduled = 0;
  int run = 0;
}

Widget _host(List<Widget> children) {
  return MaterialApp(
    home: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

Future<void> _pumpGroup(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(child);
  await tester.pump();
}

Text _text(WidgetTester tester, Key key) {
  return tester.widget<Text>(find.byKey(key));
}

double _effectiveSize(WidgetTester tester, Key key) {
  final text = _text(tester, key);
  return (text.textScaler ?? TextScaler.noScaling).scale(text.style!.fontSize!);
}

RenderParagraph _paragraph(WidgetTester tester, Key textKey) {
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
  );
}

double _selectionWidth(RenderParagraph paragraph, int start, int end) {
  return paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .fold<double>(0, (width, box) => width + (box.right - box.left).abs());
}

void main() {
  group('AutoSizeGroup heterogeneous constraints', () {
    testWidgets(
      'should project different regular grids without leaving either domain',
      (tester) async {
        final group = AutoSizeGroup();
        const firstKey = ValueKey<String>('regular-first');
        const secondKey = ValueKey<String>('regular-second');

        await _pumpGroup(
          tester,
          _host(<Widget>[
            AutoSizeText(
              '',
              textKey: firstKey,
              style: const TextStyle(fontSize: 30),
              minFontSize: 10,
              stepGranularity: 4,
              textScaler: TextScaler.noScaling,
              group: group,
            ),
            AutoSizeText(
              '',
              textKey: secondKey,
              style: const TextStyle(fontSize: 31),
              minFontSize: 11,
              stepGranularity: 5,
              textScaler: TextScaler.noScaling,
              group: group,
            ),
          ]),
        );

        expect(_effectiveSize(tester, firstKey), 30);
        expect(_effectiveSize(tester, secondKey), 26);
      },
    );

    testWidgets('should project fractional grids using exact domain values', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      const firstKey = ValueKey<String>('fractional-first');
      const secondKey = ValueKey<String>('fractional-second');

      await _pumpGroup(
        tester,
        _host(<Widget>[
          AutoSizeText(
            '',
            textKey: firstKey,
            style: const TextStyle(fontSize: 0.5),
            minFontSize: 0.3,
            stepGranularity: 0.1,
            textScaler: TextScaler.noScaling,
            group: group,
          ),
          AutoSizeText(
            '',
            textKey: secondKey,
            style: const TextStyle(fontSize: 0.45),
            minFontSize: 0.35,
            stepGranularity: 0.1,
            textScaler: TextScaler.noScaling,
            group: group,
          ),
        ]),
      );

      expect(_effectiveSize(tester, firstKey), 0.4);
      expect(_effectiveSize(tester, secondKey), 0.45);
    });

    testWidgets(
      'should keep disjoint presets stable without republishing a projection',
      (tester) async {
        final group = AutoSizeGroup();
        const firstKey = ValueKey<String>('preset-first');
        const secondKey = ValueKey<String>('preset-second');
        late StateSetter rebuild;

        await _pumpGroup(
          tester,
          _host(<Widget>[
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AutoSizeText(
                      '',
                      textKey: firstKey,
                      style: const TextStyle(fontSize: 40),
                      presetFontSizes: const <double>[40, 20, 10],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                    AutoSizeText(
                      '',
                      textKey: secondKey,
                      style: const TextStyle(fontSize: 30),
                      presetFontSizes: const <double>[30, 10],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                  ],
                );
              },
            ),
          ]),
        );

        expect(_effectiveSize(tester, firstKey), 20);
        expect(_effectiveSize(tester, secondKey), 30);

        rebuild(() {});
        await tester.pump();
        await tester.pump();
        expect(_effectiveSize(tester, firstKey), 20);
        expect(_effectiveSize(tester, secondKey), 30);
      },
    );

    testWidgets(
      'should render the local minimum when the group limit is inaccessible',
      (tester) async {
        final group = AutoSizeGroup();
        const firstKey = ValueKey<String>('minimum-first');
        const secondKey = ValueKey<String>('minimum-second');

        await _pumpGroup(
          tester,
          _host(<Widget>[
            AutoSizeText(
              '',
              textKey: firstKey,
              style: const TextStyle(fontSize: 10),
              presetFontSizes: const <double>[10],
              textScaler: TextScaler.noScaling,
              group: group,
            ),
            AutoSizeText(
              '',
              textKey: secondKey,
              style: const TextStyle(fontSize: 30),
              presetFontSizes: const <double>[30, 20],
              textScaler: TextScaler.noScaling,
              group: group,
            ),
          ]),
        );

        expect(_effectiveSize(tester, firstKey), 10);
        expect(_effectiveSize(tester, secondKey), 20);
      },
    );

    testWidgets('should compare effective sizes for different linear scalers', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      const firstKey = ValueKey<String>('linear-first');
      const secondKey = ValueKey<String>('linear-second');

      await _pumpGroup(
        tester,
        _host(<Widget>[
          AutoSizeText(
            '',
            textKey: firstKey,
            style: const TextStyle(fontSize: 30),
            presetFontSizes: const <double>[30, 20, 10],
            textScaler: TextScaler.noScaling,
            group: group,
          ),
          AutoSizeText(
            '',
            textKey: secondKey,
            style: const TextStyle(fontSize: 20),
            presetFontSizes: const <double>[20, 15, 10],
            textScaler: const TextScaler.linear(2),
            group: group,
          ),
        ]),
      );

      expect(_effectiveSize(tester, firstKey), 30);
      expect(_effectiveSize(tester, secondKey), 30);
      expect(_text(tester, secondKey).style!.fontSize, 20);
    });

    testWidgets('should project a nonlinear scaler without inverting it', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      const firstKey = ValueKey<String>('nonlinear-first');
      const secondKey = ValueKey<String>('nonlinear-second');

      await _pumpGroup(
        tester,
        _host(<Widget>[
          AutoSizeText(
            '',
            textKey: firstKey,
            style: const TextStyle(fontSize: 30),
            presetFontSizes: const <double>[30, 20, 10],
            textScaler: const _QuadraticTextScaler(),
            group: group,
          ),
          AutoSizeText(
            '',
            textKey: secondKey,
            style: const TextStyle(fontSize: 50),
            presetFontSizes: const <double>[50],
            textScaler: TextScaler.noScaling,
            group: group,
          ),
        ]),
      );

      expect(_effectiveSize(tester, firstKey), 40);
      expect(_effectiveSize(tester, secondKey), 50);
      expect(_text(tester, firstKey).style!.fontSize, 30);
    });

    testWidgets(
      'should reject a one-ulp effective excess but accept exact equality',
      (tester) async {
        Future<Text> pumpMapped(double upperResult) async {
          final group = AutoSizeGroup();
          const mappedKey = ValueKey<String>('mapped');
          await _pumpGroup(
            tester,
            _host(<Widget>[
              AutoSizeText(
                '',
                textKey: mappedKey,
                style: const TextStyle(fontSize: 30),
                presetFontSizes: const <double>[30, 20, 10],
                textScaler: _MappedTextScaler(upperResult: upperResult),
                group: group,
              ),
              AutoSizeText(
                '',
                style: const TextStyle(fontSize: 20),
                presetFontSizes: const <double>[20],
                textScaler: TextScaler.noScaling,
                group: group,
              ),
            ]),
          );
          return _text(tester, mappedKey);
        }

        var mapped = await pumpMapped(20.000000000000004);
        expect(
          (mapped.textScaler ?? TextScaler.noScaling).scale(
            mapped.style!.fontSize!,
          ),
          10,
        );

        mapped = await pumpMapped(20);
        expect(
          (mapped.textScaler ?? TextScaler.noScaling).scale(
            mapped.style!.fontSize!,
          ),
          20,
        );
        expect(mapped.style!.fontSize, 30);
      },
    );

    testWidgets(
      'should keep the locally fitting rich candidate on a scaler plateau',
      (tester) async {
        final group = AutoSizeGroup();
        const groupedKey = ValueKey<String>('plateau-grouped');
        const standaloneKey = ValueKey<String>('plateau-standalone');
        const source = TextSpan(text: 'A', style: TextStyle(fontSize: 10));

        await _pumpGroup(
          tester,
          _host(<Widget>[
            SizedBox(
              width: 12,
              height: 100,
              child: AutoSizeText.rich(
                source,
                textKey: groupedKey,
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
                presetFontSizes: const <double>[30, 20, 10],
                textScaler: const _CappedTextScaler(),
                maxLines: 1,
                softWrap: false,
                group: group,
              ),
            ),
            AutoSizeText(
              '',
              style: const TextStyle(fontSize: 20),
              presetFontSizes: const <double>[20],
              textScaler: TextScaler.noScaling,
              group: group,
            ),
            SizedBox(
              width: 12,
              height: 100,
              child: AutoSizeText.rich(
                source,
                textKey: standaloneKey,
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
                presetFontSizes: const <double>[30, 20, 10],
                textScaler: const _CappedTextScaler(),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ]),
        );

        final grouped = _text(tester, groupedKey);
        final standalone = _text(tester, standaloneKey);
        expect(grouped.textScaler, standalone.textScaler);
        expect(_selectionWidth(_paragraph(tester, groupedKey), 0, 1), 10);
      },
    );

    testWidgets('should keep the local rich candidate on a zero-root plateau', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      const groupedKey = ValueKey<String>('zero-plateau-grouped');
      const standaloneKey = ValueKey<String>('zero-plateau-standalone');
      const source = TextSpan(
        text: 'A',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 100),
      );

      await _pumpGroup(
        tester,
        _host(<Widget>[
          SizedBox(
            width: 95,
            height: 150,
            child: AutoSizeText.rich(
              source,
              textKey: groupedKey,
              style: const TextStyle(fontSize: 20),
              presetFontSizes: const <double>[30, 20, 10],
              textScaler: const _ZeroRootPlateauTextScaler(),
              maxLines: 1,
              softWrap: false,
              group: group,
            ),
          ),
          AutoSizeText(
            '',
            style: const TextStyle(fontSize: 0),
            presetFontSizes: const <double>[0],
            textScaler: TextScaler.noScaling,
            group: group,
          ),
          SizedBox(
            width: 95,
            height: 150,
            child: AutoSizeText.rich(
              source,
              textKey: standaloneKey,
              style: const TextStyle(fontSize: 20),
              presetFontSizes: const <double>[30, 20, 10],
              textScaler: const _ZeroRootPlateauTextScaler(),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ]),
      );

      expect(_effectiveSize(tester, groupedKey), 0);
      expect(_effectiveSize(tester, standaloneKey), 0);
      expect(_selectionWidth(_paragraph(tester, standaloneKey), 0, 1), 70);
      expect(_selectionWidth(_paragraph(tester, groupedKey), 0, 1), 70);

      await tester.pump();
      expect(_selectionWidth(_paragraph(tester, groupedKey), 0, 1), 70);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'should base overflow replacement only on the local fit result',
      (tester) async {
        final overflowingGroup = AutoSizeGroup();
        final inaccessibleGroup = AutoSizeGroup();
        const overflowingReplacement = ValueKey<String>(
          'overflowing-replacement',
        );
        const projectedText = ValueKey<String>('projected-text');
        const projectedReplacement = ValueKey<String>('projected-replacement');

        await _pumpGroup(
          tester,
          _host(<Widget>[
            SizedBox(
              width: 1,
              height: 1,
              child: AutoSizeText(
                'A',
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
                presetFontSizes: const <double>[20],
                textScaler: TextScaler.noScaling,
                maxLines: 1,
                group: overflowingGroup,
                overflowReplacement: const SizedBox(
                  key: overflowingReplacement,
                ),
              ),
            ),
            AutoSizeText(
              '',
              style: const TextStyle(fontSize: 40),
              presetFontSizes: const <double>[40, 20, 10],
              textScaler: TextScaler.noScaling,
              group: overflowingGroup,
            ),
            AutoSizeText(
              '',
              style: const TextStyle(fontSize: 10),
              presetFontSizes: const <double>[10],
              textScaler: TextScaler.noScaling,
              group: inaccessibleGroup,
            ),
            AutoSizeText(
              '',
              textKey: projectedText,
              style: const TextStyle(fontSize: 30),
              presetFontSizes: const <double>[30, 20],
              textScaler: TextScaler.noScaling,
              group: inaccessibleGroup,
              overflowReplacement: const SizedBox(key: projectedReplacement),
            ),
          ]),
        );

        expect(find.byKey(overflowingReplacement), findsOneWidget);
        expect(find.byKey(projectedReplacement), findsNothing);
        expect(_effectiveSize(tester, projectedText), 20);
      },
    );

    testWidgets(
      'should reject an invalid scaler result reached during projection',
      (tester) async {
        final group = AutoSizeGroup();
        const projectedKey = ValueKey<String>('invalid-projection');
        TextScaler scaler = const _ProjectionInvalidTextScaler();
        late StateSetter update;

        await tester.pumpWidget(
          _host(<Widget>[
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: AutoSizeText(
                        '',
                        textKey: projectedKey,
                        style: const TextStyle(fontSize: 50),
                        presetFontSizes: const <double>[50, 40, 30, 20, 10],
                        textScaler: scaler,
                        group: group,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: AutoSizeText(
                        '',
                        style: const TextStyle(fontSize: 25),
                        presetFontSizes: const <double>[25],
                        textScaler: TextScaler.noScaling,
                        group: group,
                      ),
                    ),
                  ],
                );
              },
            ),
          ]),
        );
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(tester.takeException(), isA<ArgumentError>());

        update(() => scaler = TextScaler.noScaling);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_effectiveSize(tester, projectedKey), 20);
      },
    );

    testWidgets(
      'should schedule and run one group microtask for synchronous decreases',
      (tester) async {
        final group = AutoSizeGroup();
        var firstSize = 40.0;
        var secondSize = 40.0;
        late StateSetter update;

        await _pumpGroup(
          tester,
          _host(<Widget>[
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AutoSizeText(
                      '',
                      style: TextStyle(fontSize: firstSize),
                      presetFontSizes: <double>[firstSize],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                    AutoSizeText(
                      '',
                      style: TextStyle(fontSize: secondSize),
                      presetFontSizes: <double>[secondSize],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                    AutoSizeText(
                      '',
                      style: const TextStyle(fontSize: 40),
                      presetFontSizes: const <double>[40, 30],
                      textScaler: TextScaler.noScaling,
                      group: group,
                    ),
                  ],
                );
              },
            ),
          ]),
        );

        final counts = _GroupMicrotaskCounts();
        await runZoned(
          () async {
            update(() {
              firstSize = 35;
              secondSize = 30;
            });
            await tester.pump();
          },
          zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (self, parent, zone, task) {
              final isGroupTask = StackTrace.current.toString().contains(
                'auto_size_group.dart',
              );
              if (!isGroupTask) {
                parent.scheduleMicrotask(zone, task);
                return;
              }
              counts.scheduled += 1;
              parent.scheduleMicrotask(zone, () {
                counts.run += 1;
                task();
              });
            },
          ),
        );

        expect(<int>[counts.scheduled, counts.run], orderedEquals(<int>[1, 1]));
        await tester.pump();
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      'should keep projection logarithmic for a trillion virtual candidates',
      (tester) async {
        final group = AutoSizeGroup();
        final counter = _ScaleCounter();
        final scaler = _CountingIdentityTextScaler(counter);
        const projectedKey = ValueKey<String>('large-projection');

        await _pumpGroup(
          tester,
          _host(<Widget>[
            SizedBox(
              width: 100,
              height: 100,
              child: AutoSizeText(
                '',
                textKey: projectedKey,
                style: const TextStyle(fontSize: 100000000000.1),
                minFontSize: 0.1,
                stepGranularity: 0.1,
                textScaler: scaler,
                group: group,
              ),
            ),
            AutoSizeText(
              '',
              style: const TextStyle(fontSize: 50),
              presetFontSizes: const <double>[50],
              textScaler: TextScaler.noScaling,
              group: group,
            ),
          ]),
        );

        expect(_effectiveSize(tester, projectedKey), 49.900000000000006);
        expect(counter.calls, lessThan(200));
      },
    );
  });
}

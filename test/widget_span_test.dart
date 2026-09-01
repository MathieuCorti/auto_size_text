import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'leak_tracking.dart';

final class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) => fontSize + fontSize * fontSize / 100;

  @override
  double get textScaleFactor => 99;
}

final class _CandidateOracleScaler extends TextScaler {
  const _CandidateOracleScaler({
    required this.candidate,
    required this.reference,
  });

  final double candidate;
  final double reference;

  @override
  double scale(double fontSize) {
    final adjusted = reference == 0
        ? fontSize
        : fontSize * candidate / reference;
    return const _NonlinearScaler().scale(adjusted);
  }

  @override
  double get textScaleFactor => 99;
}

final class _MetricCounts {
  int wetLayouts = 0;
  int dryLayouts = 0;
  int dryBaselines = 0;
  int minWidths = 0;
  int maxWidths = 0;
  int minHeights = 0;
  int maxHeights = 0;
}

final class _MetricTrap extends LeafRenderObjectWidget {
  const _MetricTrap({super.key, required this.counts});

  final _MetricCounts counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMetricTrap(counts);
}

final class _RenderMetricTrap extends RenderBox {
  _RenderMetricTrap(this.counts);

  final _MetricCounts counts;

  Never _reject(String metric) =>
      throw FlutterError('child queried for $metric');

  @override
  void performLayout() {
    counts.wetLayouts += 1;
    size = constraints.constrain(const Size(12, 8));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    counts.dryLayouts += 1;
    return _reject('dry layout');
  }

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    counts.dryBaselines += 1;
    return _reject('dry baseline');
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    counts.minWidths += 1;
    return _reject('minimum intrinsic width');
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    counts.maxWidths += 1;
    return _reject('maximum intrinsic width');
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    counts.minHeights += 1;
    return _reject('minimum intrinsic height');
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    counts.maxHeights += 1;
    return _reject('maximum intrinsic height');
  }
}

final class _PaintHitCounts {
  int paints = 0;
  int hits = 0;
}

final class _PaintHitBox extends LeafRenderObjectWidget {
  const _PaintHitBox({super.key, required this.counts});

  final _PaintHitCounts counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintHitBox(counts);
}

final class _RenderPaintHitBox extends RenderBox {
  _RenderPaintHitBox(this.counts);

  final _PaintHitCounts counts;

  @override
  void performLayout() {
    size = constraints.constrain(const Size(24, 16));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counts.paints += 1;
    context.canvas.drawRect(offset & size, Paint()..color = Colors.blue);
  }

  @override
  bool hitTestSelf(Offset position) {
    counts.hits += 1;
    return true;
  }
}

final class _LayoutCounter {
  int layouts = 0;
}

final class _CountingBox extends LeafRenderObjectWidget {
  const _CountingBox({required this.counter, this.nonMonotone = false});

  final _LayoutCounter counter;
  final bool nonMonotone;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCountingBox(counter, nonMonotone);
  }
}

final class _RenderCountingBox extends RenderBox {
  _RenderCountingBox(this.counter, this.nonMonotone);

  final _LayoutCounter counter;
  final bool nonMonotone;

  @override
  void performLayout() {
    counter.layouts += 1;
    final width = nonMonotone && constraints.maxWidth > 40 ? 120.0 : 1.0;
    size = constraints.constrain(Size(width, 1));
  }
}

final class _LifecycleCounts {
  int inits = 0;
  int disposes = 0;
}

final class _LifecycleBox extends StatefulWidget {
  const _LifecycleBox({required this.counts, required this.child});

  final _LifecycleCounts counts;
  final Widget child;

  @override
  State<_LifecycleBox> createState() => _LifecycleBoxState();
}

final class _LifecycleBoxState extends State<_LifecycleBox> {
  @override
  void initState() {
    super.initState();
    widget.counts.inits += 1;
  }

  @override
  void dispose() {
    widget.counts.disposes += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
        child: Center(child: child),
      ),
    ),
  );
}

RenderParagraph _paragraph(WidgetTester tester, Key key) {
  return tester.renderObject<RenderParagraph>(find.byKey(key));
}

List<RenderBox> _inlineChildren(RenderParagraph paragraph) {
  final result = <RenderBox>[];
  for (
    RenderBox? child = paragraph.firstChild;
    child != null;
    child = paragraph.childAfter(child)
  ) {
    result.add(child);
  }
  return result;
}

Rect _rectInParagraph(
  WidgetTester tester,
  Key childKey,
  RenderParagraph paragraph,
) {
  final child = tester.renderObject<RenderBox>(find.byKey(childKey));
  return MatrixUtils.transformRect(
    child.getTransformTo(paragraph),
    Offset.zero & child.size,
  );
}

double _effectiveRootSize(RenderParagraph paragraph) {
  return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
}

void main() {
  group('AutoSizeText WidgetSpan', () {
    testWidgets(
      'should preserve fixed constrained multiple ellipsized placeholders in preorder',
      (tester) async {
        final textKey = GlobalKey();
        final firstKey = GlobalKey();
        final secondKey = GlobalKey();
        final thirdKey = GlobalKey();
        final first = WidgetSpan(
          child: SizedBox(key: firstKey, width: 10, height: 8),
        );
        final second = WidgetSpan(
          child: ConstrainedBox(
            key: secondKey,
            constraints: const BoxConstraints.tightFor(width: 20, height: 9),
          ),
        );
        final third = WidgetSpan(
          child: SizedBox(key: thirdKey, width: 30, height: 10),
        );
        final source = TextSpan(
          children: <InlineSpan>[
            first,
            const TextSpan(text: 'x'),
            second,
            third,
          ],
        );

        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 38,
              child: AutoSizeText.rich(
                source,
                textKey: textKey,
                style: const TextStyle(fontSize: 20),
                minFontSize: 20,
                maxFontSize: 20,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );

        final paragraph = _paragraph(tester, textKey);
        final children = _inlineChildren(paragraph);
        expect(children, hasLength(3));
        expect(
          children.map((child) => (child.parentData! as TextParentData).span),
          <WidgetSpan>[first, second, third],
        );
        expect(find.byKey(firstKey), findsOneWidget);
        expect(find.byKey(secondKey), findsOneWidget);
        expect(find.byKey(thirdKey), findsOneWidget);
        expect((children.last.parentData! as TextParentData).offset, isNull);
        expect(
          identical((paragraph.text as TextSpan).children!.single, source),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('should match RichText alignment and baseline geometry', (
      tester,
    ) async {
      final autoTextKey = GlobalKey();
      final witnessTextKey = GlobalKey();
      final autoKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
      final witnessKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());

      TextSpan spans(List<GlobalKey> keys) => TextSpan(
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
        children: <InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: SizedBox(key: keys[0], width: 12, height: 8),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(key: keys[1], width: 11, height: 13),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: SizedBox(key: keys[2], width: 9, height: 6),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Baseline(
              baseline: 7,
              baselineType: TextBaseline.alphabetic,
              child: SizedBox(key: keys[3], width: 10, height: 10),
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.ideographic,
            child: Baseline(
              baseline: 5,
              baselineType: TextBaseline.ideographic,
              child: SizedBox(key: keys[4], width: 8, height: 9),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AutoSizeText.rich(
                spans(autoKeys),
                textKey: autoTextKey,
                minFontSize: 20,
                maxFontSize: 20,
              ),
              RichText(key: witnessTextKey, text: spans(witnessKeys)),
            ],
          ),
        ),
      );

      final auto = _paragraph(tester, autoTextKey);
      final witness = tester.renderObject<RenderParagraph>(
        find.byKey(witnessTextKey),
      );
      expect(auto.textSize, witness.textSize);
      for (var index = 0; index < autoKeys.length; index += 1) {
        final autoRect = _rectInParagraph(tester, autoKeys[index], auto);
        final witnessRect = _rectInParagraph(
          tester,
          witnessKeys[index],
          witness,
        );
        expect(autoRect, within(distance: 0.001, from: witnessRect));
      }
    });

    testWidgets(
      'should scale each run like RichText for nonlinear and zero runs',
      (tester) async {
        final autoTextKey = GlobalKey();
        final witnessTextKey = GlobalKey();
        final autoKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());
        final witnessKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());

        TextSpan spans(List<GlobalKey> keys) => TextSpan(
          style: const TextStyle(fontFamily: 'Ahem', fontSize: 20),
          children: <InlineSpan>[
            WidgetSpan(child: SizedBox(key: keys[0], width: 20, height: 10)),
            TextSpan(
              style: const TextStyle(fontSize: 40),
              children: <InlineSpan>[
                WidgetSpan(
                  child: SizedBox(key: keys[1], width: 20, height: 10),
                ),
              ],
            ),
            TextSpan(
              style: const TextStyle(fontSize: 0),
              children: <InlineSpan>[
                WidgetSpan(
                  child: SizedBox(key: keys[2], width: 20, height: 10),
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          _host(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AutoSizeText.rich(
                  spans(autoKeys),
                  textKey: autoTextKey,
                  style: const TextStyle(fontSize: 20),
                  minFontSize: 10,
                  maxFontSize: 10,
                  textScaler: const _NonlinearScaler(),
                ),
                RichText(
                  key: witnessTextKey,
                  text: spans(witnessKeys),
                  textScaler: const _CandidateOracleScaler(
                    candidate: 10,
                    reference: 20,
                  ),
                ),
              ],
            ),
          ),
        );

        final auto = _paragraph(tester, autoTextKey);
        final witness = tester.renderObject<RenderParagraph>(
          find.byKey(witnessTextKey),
        );
        for (var index = 0; index < autoKeys.length; index += 1) {
          final autoRect = _rectInParagraph(tester, autoKeys[index], auto);
          final witnessRect = _rectInParagraph(
            tester,
            witnessKeys[index],
            witness,
          );
          expect(autoRect, within(distance: 0.001, from: witnessRect));
          expect(autoRect.isFinite, isTrue);
        }
        expect(_rectInParagraph(tester, autoKeys.last, auto).size, Size.zero);
      },
    );

    testWidgets('should keep a zero reference finite and match RichText', (
      tester,
    ) async {
      final autoTextKey = GlobalKey();
      final witnessTextKey = GlobalKey();
      final autoKeys = List<GlobalKey>.generate(2, (_) => GlobalKey());
      final witnessKeys = List<GlobalKey>.generate(2, (_) => GlobalKey());

      TextSpan spans(List<GlobalKey> keys) => TextSpan(
        children: <InlineSpan>[
          WidgetSpan(child: SizedBox(key: keys[0], width: 20, height: 10)),
          TextSpan(
            style: const TextStyle(fontSize: 20),
            children: <InlineSpan>[
              WidgetSpan(child: SizedBox(key: keys[1], width: 20, height: 10)),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AutoSizeText.rich(
                spans(autoKeys),
                textKey: autoTextKey,
                style: const TextStyle(fontFamily: 'Ahem', fontSize: 0),
                minFontSize: 0,
                textScaler: const _NonlinearScaler(),
              ),
              RichText(
                key: witnessTextKey,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Ahem', fontSize: 0),
                  children: <InlineSpan>[spans(witnessKeys)],
                ),
                textScaler: const _NonlinearScaler(),
              ),
            ],
          ),
        ),
      );

      final auto = _paragraph(tester, autoTextKey);
      final witness = tester.renderObject<RenderParagraph>(
        find.byKey(witnessTextKey),
      );
      for (var index = 0; index < autoKeys.length; index += 1) {
        final autoRect = _rectInParagraph(tester, autoKeys[index], auto);
        final witnessRect = _rectInParagraph(
          tester,
          witnessKeys[index],
          witness,
        );
        expect(autoRect, within(distance: 0.001, from: witnessRect));
        expect(autoRect.isFinite, isTrue);
      }
      expect(_rectInParagraph(tester, autoKeys.first, auto).size, Size.zero);
    });

    testWidgets(
      'should keep six non-wet metrics at zero without querying the child',
      (tester) async {
        final autoKey = GlobalKey();
        final textKey = GlobalKey();
        final trapKey = GlobalKey();
        final counts = _MetricCounts();

        await tester.pumpWidget(
          _host(
            AutoSizeText.rich(
              TextSpan(
                style: const TextStyle(fontSize: 20),
                children: <InlineSpan>[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Baseline(
                      baseline: 6,
                      baselineType: TextBaseline.alphabetic,
                      child: _MetricTrap(key: trapKey, counts: counts),
                    ),
                  ),
                ],
              ),
              key: autoKey,
              textKey: textKey,
              minFontSize: 20,
              maxFontSize: 20,
            ),
          ),
        );

        final trap = tester.renderObject<RenderBox>(find.byKey(trapKey));
        final wrapper = trap.parent!.parent as RenderBox;
        const constraints = BoxConstraints(maxWidth: 100);
        expect(counts.wetLayouts, greaterThan(0));
        expect(wrapper.getDryLayout(constraints), Size.zero);
        expect(wrapper.getDryBaseline(constraints, TextBaseline.alphabetic), 0);
        expect(wrapper.getMinIntrinsicWidth(100), 0);
        expect(wrapper.getMaxIntrinsicWidth(100), 0);
        expect(wrapper.getMinIntrinsicHeight(100), 0);
        expect(wrapper.getMaxIntrinsicHeight(100), 0);

        final parent = tester.renderObject<RenderBox>(find.byKey(autoKey));
        expect(parent.getDryLayout(constraints).isFinite, isTrue);
        expect(
          parent.getDryBaseline(constraints, TextBaseline.alphabetic)?.isFinite,
          isTrue,
        );
        expect(parent.getMinIntrinsicWidth(100).isFinite, isTrue);
        expect(parent.getMaxIntrinsicWidth(100).isFinite, isTrue);
        expect(parent.getMinIntrinsicHeight(100).isFinite, isTrue);
        expect(parent.getMaxIntrinsicHeight(100).isFinite, isTrue);
        expect(<int>[
          counts.dryLayouts,
          counts.dryBaselines,
          counts.minWidths,
          counts.maxWidths,
          counts.minHeights,
          counts.maxHeights,
        ], everyElement(0));
      },
    );

    testWidgets('should preserve paint transform hit testing and child taps', (
      tester,
    ) async {
      final textKey = GlobalKey();
      final childKey = GlobalKey();
      final counts = _PaintHitCounts();
      var taps = 0;

      await tester.pumpWidget(
        _host(
          AutoSizeText.rich(
            TextSpan(
              style: const TextStyle(fontSize: 20),
              children: <InlineSpan>[
                WidgetSpan(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps += 1,
                    child: _PaintHitBox(key: childKey, counts: counts),
                  ),
                ),
              ],
            ),
            textKey: textKey,
            minFontSize: 10,
            maxFontSize: 10,
          ),
        ),
      );

      final paragraph = _paragraph(tester, textKey);
      final rect = _rectInParagraph(tester, childKey, paragraph);
      expect(rect.size, const Size(12, 8));
      expect(counts.paints, greaterThan(0));
      await tester.tapAt(paragraph.localToGlobal(rect.center));
      await tester.pump();
      expect(counts.hits, greaterThan(0));
      expect(taps, 1);
    });

    testWidgets(
      'should preserve child semantics recognizers and SelectionArea',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final textKey = GlobalKey();
        final childKey = GlobalKey();
        var textTaps = 0;
        var childTaps = 0;
        final recognizer = TapGestureRecognizer()..onTap = () => textTaps += 1;
        addTearDown(recognizer.dispose);

        await tester.pumpWidget(
          _host(
            SelectionArea(
              child: AutoSizeText.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 20),
                  children: <InlineSpan>[
                    TextSpan(text: 'tap', recognizer: recognizer),
                    WidgetSpan(
                      child: Semantics(
                        label: 'inline action',
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => childTaps += 1,
                          child: SizedBox(key: childKey, width: 20, height: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                textKey: textKey,
                minFontSize: 20,
                maxFontSize: 20,
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('inline action'), findsOneWidget);
        final paragraph = _paragraph(tester, textKey);
        final textBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 3),
            )
            .single;
        await tester.tapAt(paragraph.localToGlobal(textBox.toRect().center));
        await tester.pump();
        await tester.tapAt(
          paragraph.localToGlobal(
            _rectInParagraph(tester, childKey, paragraph).center,
          ),
        );
        await tester.pump();
        expect(textTaps, 1);
        expect(childTaps, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets('should support wrap maxLines groups and lazy replacement', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      final lifecycle = _LifecycleCounts();
      final firstTextKey = GlobalKey();
      final secondTextKey = GlobalKey();
      final inlineKey = GlobalKey();
      final replacementKey = GlobalKey();
      late StateSetter setHostState;
      var width = 200.0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: width,
                    height: 30,
                    child: AutoSizeText.rich(
                      TextSpan(
                        text: 'MMMM ',
                        children: <InlineSpan>[
                          WidgetSpan(
                            child: _LifecycleBox(
                              counts: lifecycle,
                              child: SizedBox(
                                key: inlineKey,
                                width: 20,
                                height: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      textKey: firstTextKey,
                      group: group,
                      minFontSize: 10,
                      maxFontSize: 20,
                      maxLines: 1,
                      softWrap: true,
                      overflowReplacement: SizedBox(
                        key: replacementKey,
                        width: 10,
                        height: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AutoSizeText.rich(
                      TextSpan(
                        text: 'MMMMMMMM',
                        children: <InlineSpan>[
                          WidgetSpan(child: SizedBox(width: 10, height: 10)),
                        ],
                      ),
                      textKey: secondTextKey,
                      group: group,
                      minFontSize: 10,
                      maxFontSize: 20,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(inlineKey), findsOneWidget);
      expect(find.byKey(replacementKey), findsNothing);
      expect(
        _effectiveRootSize(_paragraph(tester, firstTextKey)),
        _effectiveRootSize(_paragraph(tester, secondTextKey)),
      );
      setHostState(() => width = 5);
      await tester.pump();
      expect(find.byKey(firstTextKey), findsNothing);
      expect(find.byKey(inlineKey), findsNothing);
      expect(find.byKey(replacementKey), findsOneWidget);
      expect(lifecycle.disposes, 1);
    });

    testWidgets(
      'should terminate deterministically for a nonmonotone inline child',
      (tester) async {
        final textKey = GlobalKey();
        final counter = _LayoutCounter();

        Widget subject() => _host(
          SizedBox(
            width: 50,
            child: AutoSizeText.rich(
              TextSpan(
                children: <InlineSpan>[
                  WidgetSpan(
                    child: _CountingBox(counter: counter, nonMonotone: true),
                  ),
                ],
              ),
              textKey: textKey,
              style: const TextStyle(fontSize: 30),
              minFontSize: 10,
              maxFontSize: 30,
            ),
          ),
        );

        await tester.pumpWidget(subject());
        final first = _effectiveRootSize(_paragraph(tester, textKey));
        final firstLayouts = counter.layouts;
        await tester.pumpWidget(subject());
        final second = _effectiveRootSize(_paragraph(tester, textKey));
        expect(second, first);
        expect(first.isFinite, isTrue);
        expect(firstLayouts, lessThan(20));
        expect(counter.layouts - firstLayouts, lessThan(20));
      },
    );

    testWidgets('should bound placeholder layouts by P log C', (tester) async {
      final textKey = GlobalKey();
      final counters = List<_LayoutCounter>.generate(
        3,
        (_) => _LayoutCounter(),
      );
      final candidates = List<double>.generate(
        1024,
        (index) => (1024 - index).toDouble(),
      );

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 512,
            child: AutoSizeText.rich(
              TextSpan(
                children: <InlineSpan>[
                  for (final counter in counters)
                    WidgetSpan(child: _CountingBox(counter: counter)),
                ],
              ),
              textKey: textKey,
              style: const TextStyle(fontSize: 1024),
              presetFontSizes: candidates,
            ),
          ),
        ),
      );

      final layouts = counters.fold<int>(
        0,
        (sum, counter) => sum + counter.layouts,
      );
      final bound =
          counters.length * (math.log(candidates.length) / math.ln2).ceil() + 9;
      expect(layouts, lessThanOrEqualTo(bound));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'should dispose inline children across rebuild group removal and replacement',
      (tester) async {
        final group = AutoSizeGroup();
        final lifecycle = _LifecycleCounts();
        late StateSetter setHostState;
        var show = true;
        var grouped = true;
        var narrow = false;

        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                if (!show) {
                  return const SizedBox();
                }
                return SizedBox(
                  width: narrow ? 1 : 100,
                  height: 30,
                  child: AutoSizeText.rich(
                    TextSpan(
                      text: 'MMMM',
                      children: <InlineSpan>[
                        WidgetSpan(
                          child: _LifecycleBox(
                            counts: lifecycle,
                            child: const SizedBox(width: 10, height: 10),
                          ),
                        ),
                      ],
                    ),
                    group: grouped ? group : null,
                    minFontSize: 10,
                    maxFontSize: 20,
                    maxLines: 1,
                    overflowReplacement: const SizedBox(width: 1, height: 1),
                  ),
                );
              },
            ),
          ),
        );
        expect(lifecycle.inits, 1);
        setHostState(() => grouped = false);
        await tester.pump();
        expect(lifecycle.inits, 1);
        setHostState(() => narrow = true);
        await tester.pump();
        expect(lifecycle.disposes, 1);
        setHostState(() {
          narrow = false;
          show = true;
        });
        await tester.pump();
        expect(lifecycle.inits, 2);
        setHostState(() => show = false);
        await tester.pump();
        expect(lifecycle.disposes, 2);
      },
      experimentalLeakTesting: nativeResourceLeakTesting,
    );

    testWidgets('should preserve an active replacement across rebuilds', (
      tester,
    ) async {
      final lifecycle = _LifecycleCounts();
      late StateSetter setHostState;
      var revision = 0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return SizedBox(
                width: 1,
                height: 1,
                child: AutoSizeText.rich(
                  TextSpan(
                    text: revision.isEven ? 'MMMM' : 'NNNN',
                    children: const <InlineSpan>[
                      WidgetSpan(child: SizedBox(width: 20, height: 10)),
                    ],
                  ),
                  minFontSize: 20,
                  maxFontSize: 20,
                  maxLines: 1,
                  overflowReplacement: _LifecycleBox(
                    counts: lifecycle,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(lifecycle.inits, 1);
      expect(lifecycle.disposes, 0);
      setHostState(() => revision += 1);
      await tester.pump();
      expect(lifecycle.inits, 1);
      expect(lifecycle.disposes, 0);
    });

    testWidgets('should keep shared GlobalKeys exclusive during wet rebuilds', (
      tester,
    ) async {
      final sharedKey = GlobalKey();
      late StateSetter setHostState;
      var revision = 0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return SizedBox(
                width: 1,
                height: 1,
                child: AutoSizeText.rich(
                  TextSpan(
                    text: revision.isEven ? 'MMMM' : 'NNNN',
                    children: <InlineSpan>[
                      WidgetSpan(
                        child: SizedBox(
                          key: sharedKey,
                          width: 20,
                          height: 10,
                        ),
                      ),
                    ],
                  ),
                  minFontSize: 20,
                  maxFontSize: 20,
                  maxLines: 1,
                  overflowReplacement: SizedBox(key: sharedKey),
                ),
              );
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(sharedKey), findsOneWidget);
      setHostState(() => revision += 1);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(sharedKey), findsOneWidget);
    });
  });
}

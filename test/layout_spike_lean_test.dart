import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/layout_spike/lean.dart';
import '../tool/layout_spike/spike.dart';

void main() {
  group('Lean layout spike', () {
    testWidgets(
      'should keep replacement lazy and return the same minimum text fallback',
      (tester) async {
        const text = TextSpan(
          style: TextStyle(fontSize: 20),
          text: 'MMMMMMMMMM',
        );
        const narrow = BoxConstraints(maxWidth: 40, maxHeight: 30);
        final textCounters = SpikeCounters();
        final leanCounters = SpikeLeanCounters();
        final lifecycle = _LifecycleLedger();
        final outerKey = GlobalKey();
        final replacementChildKey = GlobalKey();
        late StateSetter updateWidth;
        var maxWidth = 300.0;
        var replacementBuilderCalls = 0;
        final publications = <double>[];

        await tester.pumpWidget(
          _host(
            Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateWidth = setState;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: 50,
                    ),
                    child: SpikeLeanOverflowParagraph(
                      key: outerKey,
                      text: text,
                      domain: const SpikeCandidateDomain(
                        minimum: 10,
                        maximum: 20,
                        step: 1,
                      ),
                      referenceFontSize: 20,
                      textCounters: textCounters,
                      leanCounters: leanCounters,
                      maxLines: 1,
                      softWrap: false,
                      onPublish: publications.add,
                      overflowReplacement: LayoutBuilder(
                        builder: (context, constraints) {
                          replacementBuilderCalls += 1;
                          return _LifecycleProbe(
                            ledger: lifecycle,
                            child: SpikeWetOnlyBox(
                              child: SizedBox(
                                key: replacementChildKey,
                                width: 30,
                                height: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        final outer = tester.renderObject<RenderBox>(find.byKey(outerKey));
        expect(replacementBuilderCalls, 0);
        expect(lifecycle.inits, 0);
        expect(find.byKey(replacementChildKey), findsNothing);
        expect(publications, <double>[20]);

        final expected = _minimumTextMetrics(text, narrow);
        final publicationsBeforeDry = List<double>.of(publications);
        final dryBeforeWet = <Size>[
          outer.getDryLayout(narrow),
          outer.getDryLayout(narrow),
          outer.getDryLayout(narrow),
        ];
        final baselineBeforeWet = outer.getDryBaseline(
          narrow,
          TextBaseline.alphabetic,
        );
        final intrinsicBeforeWet = <double>[
          outer.getMinIntrinsicWidth(30),
          outer.getMaxIntrinsicWidth(30),
          outer.getMinIntrinsicHeight(40),
          outer.getMaxIntrinsicHeight(40),
        ];

        expect(dryBeforeWet, everyElement(expected.size));
        expect(
          baselineBeforeWet,
          moreOrLessEquals(epsilon: 0.001, expected.baseline),
        );
        expect(intrinsicBeforeWet.every((value) => value.isFinite), isTrue);
        expect(replacementBuilderCalls, 0);
        expect(lifecycle.inits, 0);
        expect(publications, publicationsBeforeDry);
        expect(
          leanCounters.temporaryPaintersDisposed,
          leanCounters.temporaryPaintersCreated,
        );

        updateWidth(() => maxWidth = 40);
        await tester.pump();

        expect(find.byKey(replacementChildKey), findsOneWidget);
        expect(replacementBuilderCalls, greaterThan(0));
        expect(lifecycle.inits, 1);
        expect(lifecycle.disposes, 0);
        expect(outer.size, const Size(30, 40));
        expect(
          tester.renderObject<RenderBox>(find.byKey(replacementChildKey)).size,
          const Size(30, 40),
        );
        final builderCallsAfterWet = replacementBuilderCalls;
        final publicationsAfterWet = List<double>.of(publications);
        const alternateNarrow = BoxConstraints(maxWidth: 39, maxHeight: 30);
        final alternateExpected = _minimumTextMetrics(text, alternateNarrow);

        final dryAfterWet = <Size>[
          outer.getDryLayout(narrow),
          outer.getDryLayout(narrow),
        ];
        final alternateDryAfterWet = outer.getDryLayout(alternateNarrow);
        final baselineAfterWet = outer.getDryBaseline(
          narrow,
          TextBaseline.alphabetic,
        );
        final intrinsicAfterWet = <double>[
          outer.getMinIntrinsicWidth(30),
          outer.getMaxIntrinsicWidth(30),
          outer.getMinIntrinsicHeight(40),
          outer.getMaxIntrinsicHeight(40),
        ];

        expect(dryAfterWet, everyElement(expected.size));
        expect(dryAfterWet.first, dryBeforeWet.first);
        expect(alternateDryAfterWet, alternateExpected.size);
        expect(
          baselineAfterWet,
          moreOrLessEquals(epsilon: 0.001, baselineBeforeWet!),
        );
        expect(intrinsicAfterWet, intrinsicBeforeWet);
        expect(replacementBuilderCalls, builderCallsAfterWet);
        expect(lifecycle.inits, 1);
        expect(publications, publicationsAfterWet);
        expect(
          leanCounters.temporaryPaintersDisposed,
          leanCounters.temporaryPaintersCreated,
        );

        updateWidth(() => maxWidth = 300);
        await tester.pump();

        expect(find.byKey(replacementChildKey), findsNothing);
        expect(lifecycle.disposes, 1);
        expect(outer.getDryLayout(narrow), expected.size);
        expect(lifecycle.inits, 1);
        expect(replacementBuilderCalls, builderCallsAfterWet);
        expect(leanCounters.publications, 3);

        debugPrint(
          'SPIKE_LEAN_LAZY dry=${expected.size} '
          'baseline=${expected.baseline.toStringAsFixed(3)} '
          'wetReplacement=${const Size(30, 40)} '
          'replacementBuilds=$replacementBuilderCalls '
          'lifecycle=${lifecycle.inits}/${lifecycle.disposes} '
          'painters=${leanCounters.temporaryPaintersCreated}/'
          '${leanCounters.temporaryPaintersDisposed}',
        );
      },
    );

    testWidgets(
      'should keep text-only intrinsics exact while replacement is unmounted',
      (tester) async {
        const text = TextSpan(
          style: TextStyle(fontSize: 20),
          text: 'exact intrinsic metrics',
        );
        final leanCounters = SpikeLeanCounters();
        final leanTextCounters = SpikeCounters();
        final witnessCounters = SpikeCounters();
        final leanKey = GlobalKey();
        final witnessKey = GlobalKey();
        var replacementBuilds = 0;

        await tester.pumpWidget(
          _host(
            Row(
              children: <Widget>[
                Expanded(
                  child: SpikeLeanOverflowParagraph(
                    key: leanKey,
                    text: text,
                    domain: const SpikeCandidateDomain(
                      minimum: 20,
                      maximum: 20,
                      step: 1,
                    ),
                    referenceFontSize: 20,
                    textCounters: leanTextCounters,
                    leanCounters: leanCounters,
                    overflowReplacement: Builder(
                      builder: (context) {
                        replacementBuilds += 1;
                        return const SizedBox(width: 1, height: 1);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: SpikeAutoParagraph(
                    key: witnessKey,
                    text: text,
                    domain: const SpikeCandidateDomain(
                      minimum: 20,
                      maximum: 20,
                      step: 1,
                    ),
                    referenceFontSize: 20,
                    counters: witnessCounters,
                  ),
                ),
              ],
            ),
          ),
        );

        final lean = tester.renderObject<RenderBox>(find.byKey(leanKey));
        final witness = tester.renderObject<RenderBox>(find.byKey(witnessKey));
        final leanValues = <double>[
          lean.getMinIntrinsicWidth(100),
          lean.getMaxIntrinsicWidth(100),
          lean.getMinIntrinsicHeight(200),
          lean.getMaxIntrinsicHeight(200),
        ];
        final witnessValues = <double>[
          witness.getMinIntrinsicWidth(100),
          witness.getMaxIntrinsicWidth(100),
          witness.getMinIntrinsicHeight(200),
          witness.getMaxIntrinsicHeight(200),
        ];

        expect(leanValues, witnessValues);
        expect(replacementBuilds, 0);
        expect(leanCounters.publications, 1);
        expect(
          leanCounters.temporaryPaintersDisposed,
          leanCounters.temporaryPaintersCreated,
        );
      },
    );

    testWidgets(
      'should use a zero dry placeholder without querying a wet-only child',
      (tester) async {
        final textCounters = SpikeCounters();
        final leanCounters = SpikeLeanCounters();
        final placeholderKey = GlobalKey();
        final wetChildKey = GlobalKey();

        await tester.pumpWidget(
          _host(
            Center(
              child: SpikeAutoParagraph(
                text: TextSpan(
                  style: const TextStyle(fontSize: 20),
                  children: <InlineSpan>[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: SpikeLeanDryPlaceholder(
                        key: placeholderKey,
                        counters: leanCounters,
                        child: SpikeLeanWetOnlyTrap(
                          child: Baseline(
                            baseline: 6,
                            baselineType: TextBaseline.alphabetic,
                            child: SizedBox(
                              key: wetChildKey,
                              width: 12,
                              height: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                domain: const SpikeCandidateDomain(
                  minimum: 20,
                  maximum: 20,
                  step: 1,
                ),
                referenceFontSize: 20,
                counters: textCounters,
              ),
            ),
          ),
        );

        final paragraph = tester.renderObject<RenderBox>(
          find.byType(SpikeAutoParagraph),
        );
        final placeholder = tester.renderObject<RenderBox>(
          find.byKey(placeholderKey),
        );
        final wetChild = tester.renderObject<RenderBox>(
          find.byKey(wetChildKey),
        );
        const dryConstraints = BoxConstraints(maxWidth: 100);

        expect(wetChild.size, const Size(12, 8));
        expect(placeholder.size.width, 12);
        expect(placeholder.size.height, greaterThan(0));
        expect(leanCounters.placeholderWetLayouts, greaterThan(0));
        expect(placeholder.getDryLayout(dryConstraints), Size.zero);
        expect(
          placeholder.getDryBaseline(dryConstraints, TextBaseline.alphabetic),
          0,
        );
        expect(placeholder.getMinIntrinsicWidth(100), 0);
        expect(placeholder.getMaxIntrinsicWidth(100), 0);
        expect(placeholder.getMinIntrinsicHeight(100), 0);
        expect(placeholder.getMaxIntrinsicHeight(100), 0);
        final drySize = paragraph.getDryLayout(dryConstraints);
        final dryBaseline = paragraph.getDryBaseline(
          dryConstraints,
          TextBaseline.alphabetic,
        );
        expect(drySize.width, lessThan(paragraph.size.width));
        expect(dryBaseline, isNonNegative);
        expect(leanCounters.placeholderDryLayouts, greaterThan(0));
        expect(leanCounters.placeholderDryBaselines, greaterThan(0));
        expect(paragraph.getMinIntrinsicWidth(100), isNonNegative);
        expect(paragraph.getMaxIntrinsicWidth(100), isNonNegative);
        expect(paragraph.getMinIntrinsicHeight(100), isNonNegative);
        expect(paragraph.getMaxIntrinsicHeight(100), isNonNegative);
        expect(leanCounters.placeholderMinIntrinsicWidths, greaterThan(0));
        expect(leanCounters.placeholderMaxIntrinsicWidths, greaterThan(0));
        expect(leanCounters.placeholderMinIntrinsicHeights, greaterThan(0));
        expect(leanCounters.placeholderMaxIntrinsicHeights, greaterThan(0));

        debugPrint(
          'SPIKE_LEAN_PLACEHOLDER wet=${placeholder.size} '
          'dry=${placeholder.getDryLayout(dryConstraints)} '
          'baseline=0 childDry=never',
        );
      },
    );

    testWidgets('should keep a zero reference finite and non-throwing', (
      tester,
    ) async {
      final leanCounters = SpikeLeanCounters();
      final key = GlobalKey();

      await tester.pumpWidget(
        _host(
          SpikeLeanOverflowParagraph(
            key: key,
            text: const TextSpan(style: TextStyle(fontSize: 0), text: 'zero'),
            domain: const SpikeCandidateDomain(minimum: 0, maximum: 0, step: 1),
            referenceFontSize: 0,
            textCounters: SpikeCounters(),
            leanCounters: leanCounters,
            overflowReplacement: const SizedBox(width: 1, height: 1),
          ),
        ),
      );

      final render = tester.renderObject<RenderBox>(find.byKey(key));
      final dry = render.getDryLayout(const BoxConstraints(maxWidth: 100));
      final baseline = render.getDryBaseline(
        const BoxConstraints(maxWidth: 100),
        TextBaseline.alphabetic,
      );
      expect(dry.width.isFinite && dry.height.isFinite, isTrue);
      expect(baseline?.isFinite, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

({Size size, double baseline}) _minimumTextMetrics(
  InlineSpan text,
  BoxConstraints constraints,
) {
  final painter = TextPainter(
    text: text,
    textDirection: TextDirection.ltr,
    textScaler: const SpikeCandidateScaler(
      source: TextScaler.noScaling,
      candidate: 10,
      reference: 20,
    ),
    maxLines: 1,
  )..layout(maxWidth: double.infinity);
  try {
    return (
      size: constraints.constrain(painter.size),
      baseline: painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      ),
    );
  } finally {
    painter.dispose();
  }
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

final class _LifecycleLedger {
  int inits = 0;
  int disposes = 0;
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.ledger, required this.child});

  final _LifecycleLedger ledger;
  final Widget child;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.ledger.inits += 1;
  }

  @override
  void dispose() {
    widget.ledger.disposes += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/layout_spike/evidence.dart';
import '../tool/layout_spike/spike.dart';

void main() {
  group('Layout spike archived evidence', () {
    testWidgets('should reproduce the exact lazy dry stale branch blocker', (
      tester,
    ) async {
      final ledger = EvidenceBranchLedger();
      final lazyKey = GlobalKey();
      late StateSetter updateWidth;
      var maxWidth = 150.0;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateWidth = setState;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: EvidenceLazySwitch(key: lazyKey, ledger: ledger),
                );
              },
            ),
          ),
        ),
      );

      final lazy = tester.renderObject<RenderBox>(find.byKey(lazyKey));
      expect(lazy.size, const Size(120, 70));
      expect(ledger.inits, <String, int>{'text': 1});
      expect(ledger.disposes, isEmpty);
      expect(find.bySemanticsLabel('text branch'), findsOneWidget);
      expect(find.bySemanticsLabel('replacement branch'), findsNothing);
      await tester.tap(find.bySemanticsLabel('text branch'));
      expect(ledger.taps, <String, int>{'text': 1});

      final lifecycleBeforeDry = Map<String, int>.of(ledger.inits);
      final drySize = lazy.getDryLayout(const BoxConstraints(maxWidth: 50));
      expect(drySize, const Size(50, 70));
      expect(ledger.inits, lifecycleBeforeDry);
      expect(ledger.disposes, isEmpty);
      expect(ledger.dryLayouts, <String, int>{'text': 1});

      updateWidth(() => maxWidth = 50);
      await tester.pump();
      expect(lazy.size, const Size(30, 40));
      expect(ledger.inits, <String, int>{'text': 1, 'replacement': 1});
      expect(ledger.disposes, <String, int>{'text': 1});
      expect(find.bySemanticsLabel('text branch'), findsNothing);
      expect(find.bySemanticsLabel('replacement branch'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('replacement branch'));
      expect(ledger.taps, <String, int>{'text': 1, 'replacement': 1});

      updateWidth(() => maxWidth = 150);
      await tester.pump();
      expect(lazy.size, const Size(120, 70));
      expect(ledger.inits, <String, int>{'text': 2, 'replacement': 1});
      expect(ledger.disposes, <String, int>{'text': 1, 'replacement': 1});
      expect(ledger.wetLayouts, <String, int>{'text': 2, 'replacement': 1});
      expect(ledger.hitTests['text'], greaterThan(0));
      expect(ledger.hitTests['replacement'], greaterThan(0));

      debugPrint(
        'SPIKE2_LAZY wetFit=120x70 dryStale=50x70 '
        'wetReplacement=30x40 inits=${ledger.inits} '
        'disposes=${ledger.disposes} layouts=${ledger.wetLayouts} '
        'dry=${ledger.dryLayouts} taps=${ledger.taps}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(ledger.disposes, <String, int>{'text': 2, 'replacement': 1});
      semantics.dispose();
    });

    testWidgets(
      'should prove eager mounting does not make LayoutBuilder dry capable',
      (tester) async {
        final key = GlobalKey<SpikeEagerReplacementState>();
        await tester.pumpWidget(
          _host(
            SpikeEagerReplacement(
              key: key,
              text: const SizedBox(width: 20, height: 20),
              replacement: LayoutBuilder(
                builder: (context, constraints) =>
                    const SizedBox(width: 30, height: 40),
              ),
            ),
          ),
        );
        key.currentState!.showResult(fits: false);
        await tester.pump();

        final stack = tester.renderObject<RenderBox>(
          find.descendant(
            of: find.byType(SpikeEagerReplacement),
            matching: find.byType(Stack),
          ),
        );
        expect(
          () => stack.getDryLayout(const BoxConstraints(maxWidth: 100)),
          throwsFlutterError,
        );
      },
    );

    testWidgets(
      'should prove eager mounting does not make a wet-only subtree dry capable',
      (tester) async {
        final key = GlobalKey<SpikeEagerReplacementState>();
        await tester.pumpWidget(
          _host(
            SpikeEagerReplacement(
              key: key,
              text: const SizedBox(width: 20, height: 20),
              replacement: const SpikeWetOnlyBox(
                child: SizedBox(width: 30, height: 40),
              ),
            ),
          ),
        );
        key.currentState!.showResult(fits: false);
        await tester.pump();

        final stack = tester.renderObject<RenderBox>(
          find.descendant(
            of: find.byType(SpikeEagerReplacement),
            matching: find.byType(Stack),
          ),
        );
        expect(
          () => stack.getDryLayout(const BoxConstraints(maxWidth: 100)),
          throwsFlutterError,
        );
      },
    );

    testWidgets(
      'should match four exact intrinsics and use dedicated child APIs',
      (tester) async {
        final spikeCounters = EvidenceIntrinsicCounters();
        final witnessCounters = EvidenceIntrinsicCounters();
        final layoutCounters = SpikeCounters();
        final spikeKey = GlobalKey();
        final witnessKey = GlobalKey();

        await tester.pumpWidget(
          _host(
            Row(
              children: <Widget>[
                Expanded(
                  child: SpikeAutoParagraph(
                    key: spikeKey,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 20),
                      children: <InlineSpan>[
                        WidgetSpan(
                          child: EvidenceIntrinsicBox(counters: spikeCounters),
                        ),
                      ],
                    ),
                    domain: const SpikeCandidateDomain(
                      minimum: 20,
                      maximum: 20,
                      step: 1,
                    ),
                    referenceFontSize: 20,
                    counters: layoutCounters,
                  ),
                ),
                Expanded(
                  child: RichText(
                    key: witnessKey,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 20),
                      children: <InlineSpan>[
                        WidgetSpan(
                          child: EvidenceIntrinsicBox(
                            counters: witnessCounters,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final spike = tester.renderObject<RenderBox>(find.byKey(spikeKey));
        final witness = tester.renderObject<RenderParagraph>(
          find.byKey(witnessKey),
        );
        spikeCounters.reset();
        witnessCounters.reset();

        final spikeValues = <double>[
          spike.getMinIntrinsicWidth(100),
          spike.getMaxIntrinsicWidth(100),
          spike.getMinIntrinsicHeight(80),
          spike.getMaxIntrinsicHeight(80),
        ];
        final witnessValues = <double>[
          witness.getMinIntrinsicWidth(100),
          witness.getMaxIntrinsicWidth(100),
          witness.getMinIntrinsicHeight(80),
          witness.getMaxIntrinsicHeight(80),
        ];

        expect(spikeValues, witnessValues);
        expect(spikeValues, <double>[11, 37, 20, 20]);
        expect(spike.getMinIntrinsicWidth(double.infinity), 11);
        expect(spike.getMaxIntrinsicWidth(double.infinity), 37);
        expect(spike.getMinIntrinsicHeight(double.infinity), 20);
        expect(spike.getMaxIntrinsicHeight(double.infinity), 20);
        expect(spikeCounters.minWidths, greaterThan(0));
        expect(spikeCounters.maxWidths, greaterThan(0));
        expect(spikeCounters.dryLayouts, greaterThan(0));
        expect(spikeCounters.minHeights, 0);
        expect(spikeCounters.maxHeights, 0);
        expect(witnessCounters.minWidths, greaterThan(0));
        expect(witnessCounters.maxWidths, greaterThan(0));
        expect(witnessCounters.dryLayouts, greaterThan(0));
        expect(witnessCounters.minHeights, 0);
        expect(witnessCounters.maxHeights, 0);

        debugPrint(
          'SPIKE2_INTRINSICS values=$spikeValues '
          'spikeMin=${spikeCounters.minWidths} '
          'spikeMax=${spikeCounters.maxWidths} '
          'spikeDry=${spikeCounters.dryLayouts}',
        );
      },
    );

    testWidgets(
      'should preserve the zero-run dry baseline failure of its child',
      (tester) async {
        final counters = SpikeCounters();
        await tester.pumpWidget(
          _host(
            SpikeInlineScaleProbe(
              runFontSize: 0,
              scaler: TextScaler.noScaling,
              counters: counters,
              child: const EvidenceNoDryBaselineBox(),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(
          find.byType(SpikeInlineScaleProbe),
        );
        expect(
          () => render.getDryBaseline(
            const BoxConstraints(maxWidth: 100),
            TextBaseline.alphabetic,
          ),
          throwsFlutterError,
        );
      },
    );

    testWidgets(
      'should map a valid zero-run child baseline to zero and dispose its wrapper',
      (tester) async {
        final counters = SpikeCounters();
        await tester.pumpWidget(
          _host(
            SpikeInlineScaleProbe(
              runFontSize: 0,
              scaler: TextScaler.noScaling,
              counters: counters,
              child: const EvidenceDryBaselineBox(),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(
          find.byType(SpikeInlineScaleProbe),
        );
        expect(
          render.getDryLayout(const BoxConstraints(maxWidth: 100)),
          Size.zero,
        );
        expect(
          render.getDryBaseline(
            const BoxConstraints(maxWidth: 100),
            TextBaseline.alphabetic,
          ),
          0,
        );
        expect(render.size, Size.zero);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(counters.inlineWrapperDisposals, 1);
      },
    );

    testWidgets('should expose the stale dry cache after an unmarked factor', (
      tester,
    ) async {
      final counters = SpikeCounters();
      await tester.pumpWidget(
        _host(
          SpikeInlineScaleProbe(
            runFontSize: 12,
            scaler: TextScaler.noScaling,
            counters: counters,
            child: const SizedBox(width: 12, height: 8),
          ),
        ),
      );

      final render = tester.renderObject<RenderBox>(
        find.byType(SpikeInlineScaleProbe),
      );
      const constraints = BoxConstraints(maxWidth: 100);
      expect(render.getDryLayout(constraints), const Size(12, 8));
      spikeSetScaleWithoutInvalidation(render, 2);
      expect(render.getDryLayout(constraints), const Size(12, 8));
      expect(
        spikePureDrySizeAtScale(render, constraints, 2),
        const Size(24, 16),
      );

      debugPrint('SPIKE2_DRY_CACHE cached=12x8 explicitFactor2=24x16');
    });

    testWidgets(
      'should perform exactly three paragraph layouts and six inline layouts',
      (tester) async {
        final counters = SpikeCounters();
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 500,
              height: 100,
              child: SpikeAutoParagraph(
                text: const TextSpan(
                  style: TextStyle(fontSize: 4),
                  children: <InlineSpan>[
                    TextSpan(text: 'three cycles'),
                    WidgetSpan(child: SizedBox(width: 4, height: 5)),
                    WidgetSpan(child: SizedBox(width: 6, height: 7)),
                  ],
                ),
                domain: const SpikeCandidateDomain(
                  minimum: 1,
                  maximum: 4,
                  step: 1,
                ),
                referenceFontSize: 4,
                counters: counters,
              ),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(
          find.byType(SpikeAutoParagraph),
        );
        expect(counters.candidateEvaluations, 3);
        expect(counters.paragraphWetLayouts, 3);
        expect(counters.childWetLayouts, 6);
        expect(render.spikeWetCandidate, 4);
        expect(render.spikeConfiguredCandidate, 4);
        expect(render.spikeInlineScales, <double>[1, 1]);

        debugPrint(
          'SPIKE2_CALLBACK paragraph=${counters.paragraphWetLayouts} '
          'leaves=${counters.childWetLayouts} final=4',
        );
      },
    );

    testWidgets('should reject paragraph self mutation during layout', (
      tester,
    ) async {
      final recorder = EvidenceMutationRecorder();
      await tester.pumpWidget(
        _host(EvidenceSelfMutationWidget(recorder: recorder)),
      );
      expect(tester.takeException(), isNull);
      expect(
        recorder.error.toString(),
        contains('mutated in its own performLayout'),
      );
    });

    testWidgets('should reject ordinary parent mutation during layout', (
      tester,
    ) async {
      final recorder = EvidenceMutationRecorder();
      await tester.pumpWidget(
        _host(
          EvidenceParentMutationWidget(
            recorder: recorder,
            child: RichText(
              text: const TextSpan(text: 'parent mutation'),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        recorder.error.toString(),
        contains('must not mutate its descendants'),
      );
    });

    testWidgets(
      'should preserve inline paint hit transform selection semantics tags and disposal',
      (tester) async {
        final counters = SpikeCounters();
        final interactions = EvidenceInteractionCounters();
        final inlineKey = GlobalKey();
        var textTaps = 0;
        final recognizer = TapGestureRecognizer()..onTap = () => textTaps += 1;
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          _host(
            SelectionArea(
              child: SizedBox(
                width: 220,
                child: SpikeAutoParagraph(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 20),
                    children: <InlineSpan>[
                      TextSpan(text: 'Tap', recognizer: recognizer),
                      WidgetSpan(
                        child: Semantics(
                          label: 'interactive inline evidence',
                          button: true,
                          child: EvidenceInteractiveBox(
                            key: inlineKey,
                            counters: interactions,
                          ),
                        ),
                      ),
                      const TextSpan(text: 'tail'),
                    ],
                  ),
                  domain: const SpikeCandidateDomain(
                    minimum: 10,
                    maximum: 10,
                    step: 1,
                  ),
                  referenceFontSize: 20,
                  counters: counters,
                ),
              ),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(
          find.byType(SpikeAutoParagraph),
        );
        final inline = tester.renderObject<RenderBox>(find.byKey(inlineKey));
        expect(interactions.paints, greaterThan(0));
        expect(
          inline.getTransformTo(render.spikeParagraph).getMaxScaleOnAxis(),
          moreOrLessEquals(0.5, epsilon: 0.001),
        );
        await tester.tapAt(
          inline.localToGlobal(inline.size.center(Offset.zero)),
        );
        expect(interactions.hitTests, greaterThan(0));
        expect(interactions.pointerDowns, 1);

        final inlineNode = tester.getSemantics(
          find.bySemanticsLabel('interactive inline evidence'),
        );
        expect(
          inlineNode.tags,
          contains(const PlaceholderSpanIndexSemanticsTag(0)),
        );
        expect(render.spikeParagraph.registrar, isNotNull);
        final textBox = render.spikeParagraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 3),
            )
            .first;
        await tester.tapAt(
          render.spikeParagraph.localToGlobal(textBox.toRect().center),
        );
        expect(textTaps, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(counters.inlineWrapperDisposals, 1);
        expect(counters.paragraphDisposals, 1);
        semantics.dispose();
        recognizer.dispose();
      },
    );
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

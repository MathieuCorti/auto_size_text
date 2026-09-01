import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/layout_spike/spike.dart';

void main() {
  group('Layout spike gate', () {
    testWidgets('should keep candidate and placeholder work logarithmic', (
      tester,
    ) async {
      final counters = SpikeCounters();
      const placeholderCount = 3;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 180,
            height: 70,
            child: SpikeAutoParagraph(
              text: const TextSpan(
                style: TextStyle(fontSize: 1024),
                children: <InlineSpan>[
                  TextSpan(text: 'MMMMMMMMMMMMMMMMMMMM'),
                  WidgetSpan(child: SizedBox(width: 4, height: 5)),
                  WidgetSpan(child: SizedBox(width: 5, height: 6)),
                  WidgetSpan(child: SizedBox(width: 6, height: 7)),
                ],
              ),
              domain: const SpikeCandidateDomain(
                minimum: 1,
                maximum: 1024,
                step: 1,
              ),
              referenceFontSize: 1024,
              counters: counters,
            ),
          ),
        ),
      );

      expect(counters.candidateEvaluations, lessThanOrEqualTo(12));
      expect(
        counters.childWetLayouts,
        lessThanOrEqualTo(placeholderCount * counters.candidateEvaluations),
      );
      expect(counters.paragraphWetLayouts, counters.candidateEvaluations);
      expect(counters.outerPerformLayouts, 1);
      expect(renderConfiguredCandidate(tester), renderWetCandidate(tester));
      debugPrint(
        'SPIKE_COUNTERS C=1024 P=$placeholderCount '
        'evaluations=${counters.candidateEvaluations} '
        'paragraph=${counters.paragraphWetLayouts} '
        'children=${counters.childWetLayouts}',
      );

      final evaluations = counters.candidateEvaluations;
      final childLayouts = counters.childWetLayouts;
      await tester.pump();
      expect(counters.candidateEvaluations, evaluations);
      expect(counters.childWetLayouts, childLayouts);
      expect(counters.outerPerformLayouts, 1);
    });

    for (final alignment in <PlaceholderAlignment>[
      PlaceholderAlignment.top,
      PlaceholderAlignment.middle,
      PlaceholderAlignment.bottom,
      PlaceholderAlignment.aboveBaseline,
      PlaceholderAlignment.belowBaseline,
      PlaceholderAlignment.baseline,
    ]) {
      testWidgets('should match dry and wet size and baseline for $alignment', (
        tester,
      ) async {
        final counters = SpikeCounters();
        await tester.pumpWidget(
          _host(
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140, maxHeight: 70),
                child: SpikeAutoParagraph(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 20),
                    children: <InlineSpan>[
                      const TextSpan(text: 'A'),
                      WidgetSpan(
                        alignment: alignment,
                        baseline: switch (alignment) {
                          PlaceholderAlignment.aboveBaseline ||
                          PlaceholderAlignment.belowBaseline ||
                          PlaceholderAlignment.baseline =>
                            TextBaseline.alphabetic,
                          _ => null,
                        },
                        child: const Baseline(
                          baseline: 8,
                          baselineType: TextBaseline.alphabetic,
                          child: SizedBox(width: 12, height: 10),
                        ),
                      ),
                      const TextSpan(text: 'B'),
                    ],
                  ),
                  domain: const SpikeCandidateDomain(
                    minimum: 10,
                    maximum: 20,
                    step: 1,
                  ),
                  referenceFontSize: 20,
                  counters: counters,
                ),
              ),
            ),
          ),
        );

        final render = _render(tester);
        final drySize = render.getDryLayout(render.constraints);
        final dryBaseline = render.getDryBaseline(
          render.constraints,
          TextBaseline.alphabetic,
        );
        final wetBaseline = render.spikeWetBaseline;
        expect(drySize, render.size);
        expect(dryBaseline, moreOrLessEquals(epsilon: 0.001, wetBaseline!));
        expect(
          render.spikeDryCandidate(render.constraints),
          render.spikeWetCandidate,
        );
      });
    }

    testWidgets(
      'should scale inline runs independently and avoid division for a zero run',
      (tester) async {
        final counters = SpikeCounters();
        const scaler = _QuadraticScaler();
        const source = TextSpan(
          style: TextStyle(fontSize: 20),
          children: <InlineSpan>[
            WidgetSpan(child: SizedBox(width: 10, height: 12)),
            TextSpan(
              style: TextStyle(fontSize: 40),
              children: <InlineSpan>[
                WidgetSpan(child: SizedBox(width: 10, height: 12)),
              ],
            ),
            TextSpan(
              style: TextStyle(fontSize: 0),
              children: <InlineSpan>[
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Baseline(
                    baseline: 6,
                    baselineType: TextBaseline.alphabetic,
                    child: SizedBox(width: 10, height: 12),
                  ),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          _host(
            Row(
              children: <Widget>[
                Expanded(
                  child: SpikeAutoParagraph(
                    text: source,
                    domain: const SpikeCandidateDomain(
                      minimum: 10,
                      maximum: 10,
                      step: 1,
                    ),
                    referenceFontSize: 20,
                    userScaler: scaler,
                    counters: counters,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: source,
                    textScaler: const SpikeCandidateScaler(
                      source: scaler,
                      candidate: 10,
                      reference: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final render = _render(tester);
        expect(render.spikeInlineScales[0], moreOrLessEquals(0.55));
        expect(render.spikeInlineScales[1], moreOrLessEquals(0.6));
        expect(render.spikeInlineScales[2], 0);
        final witness = tester.renderObject<RenderParagraph>(
          find.byType(RichText),
        );
        expect(
          render.spikeParagraph.textSize.width,
          moreOrLessEquals(epsilon: 0.001, witness.textSize.width),
        );
        expect(
          render.spikeParagraph.textSize.height,
          moreOrLessEquals(epsilon: 0.001, witness.textSize.height),
        );
        expect(
          render.spikeWetBaseline,
          moreOrLessEquals(
            epsilon: 0.001,
            render.getDryBaseline(render.constraints, TextBaseline.alphabetic)!,
          ),
        );
      },
    );

    testWidgets('should update the public paragraph span and scaler setters', (
      tester,
    ) async {
      final counters = SpikeCounters();
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 120,
            child: SpikeAutoParagraph(
              text: const TextSpan(
                style: TextStyle(fontSize: 20),
                text: 'first',
              ),
              domain: const SpikeCandidateDomain(
                minimum: 10,
                maximum: 20,
                step: 1,
              ),
              referenceFontSize: 20,
              maxLines: 1,
              counters: counters,
            ),
          ),
        ),
      );
      final first = _render(tester);
      final firstCandidate = first.spikeWetCandidate;
      expect(first.spikeParagraph.text.toPlainText(), 'first');
      expect(first.spikeParagraph.textScaler, isA<SpikeCandidateScaler>());

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 120,
            child: SpikeAutoParagraph(
              text: const TextSpan(
                style: TextStyle(fontSize: 20),
                text: 'a much longer second value',
              ),
              domain: const SpikeCandidateDomain(
                minimum: 10,
                maximum: 20,
                step: 1,
              ),
              referenceFontSize: 20,
              userScaler: const TextScaler.linear(1.25),
              maxLines: 1,
              counters: counters,
            ),
          ),
        ),
      );
      final second = _render(tester);
      expect(second.spikeParagraph.text.toPlainText(), contains('second'));
      expect(second.spikeParagraph.textScaler, isA<SpikeCandidateScaler>());
      expect(second.spikeWetCandidate, lessThan(firstCandidate!));
    });

    testWidgets(
      'should use wet child layout normally and fail only when dry is requested',
      (tester) async {
        final counters = SpikeCounters();
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 100,
              height: 60,
              child: SpikeAutoParagraph(
                text: const TextSpan(
                  style: TextStyle(fontSize: 20),
                  children: <InlineSpan>[
                    WidgetSpan(
                      child: SpikeWetOnlyBox(
                        child: SizedBox(width: 20, height: 15),
                      ),
                    ),
                  ],
                ),
                domain: const SpikeCandidateDomain(
                  minimum: 10,
                  maximum: 20,
                  step: 1,
                ),
                referenceFontSize: 20,
                counters: counters,
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final render = _render(tester);
        expect(render.spikeWetCandidate, isNotNull);
        final dryQueriesBeforeIntrinsics = counters.childDryQueries;
        expect(render.getMinIntrinsicWidth(60), isNonNegative);
        expect(render.getMaxIntrinsicWidth(60), isNonNegative);
        expect(counters.childDryQueries, dryQueriesBeforeIntrinsics);
        expect(
          () => render.spikeDryCandidate(render.constraints),
          throwsA(isA<FlutterError>()),
        );
        debugPrint(
          'SPIKE_WET_ONLY intrinsicDryQueries=$dryQueriesBeforeIntrinsics '
          'wetCandidate=${render.spikeWetCandidate}',
        );
      },
    );

    testWidgets(
      'should use an immutable group snapshot and never publish from dry queries',
      (tester) async {
        final counters = SpikeCounters();
        final published = <double>[];
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 300,
              child: SpikeAutoParagraph(
                text: const TextSpan(
                  style: TextStyle(fontSize: 40),
                  text: 'group snapshot',
                ),
                domain: const SpikeCandidateDomain(
                  minimum: 10,
                  maximum: 40,
                  step: 1,
                ),
                referenceFontSize: 40,
                groupLimit: 18,
                counters: counters,
                onPublish: published.add,
              ),
            ),
          ),
        );
        final render = _render(tester);
        expect(render.spikeWetCandidate, lessThanOrEqualTo(18));
        expect(render.spikeConfiguredCandidate, render.spikeWetCandidate);
        expect(counters.finalRelayouts, 1);
        expect(published, hasLength(1));
        debugPrint(
          'SPIKE_GROUP local=${published.single} '
          'render=${render.spikeWetCandidate} '
          'finalRelayouts=${counters.finalRelayouts}',
        );

        counters.publications = 0;
        final before = List<double>.of(published);
        for (var index = 0; index < 3; index += 1) {
          expect(
            render.spikeDryCandidate(render.constraints),
            render.spikeWetCandidate,
          );
        }
        expect(counters.publications, 0);
        expect(published, before);
      },
    );

    testWidgets(
      'should return a deterministic safe result for a non-monotone child',
      (tester) async {
        final counters = SpikeCounters();
        Widget build() {
          return _host(
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100, maxHeight: 20),
                child: SpikeAutoParagraph(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 1),
                    children: <InlineSpan>[
                      WidgetSpan(child: SpikeNonMonotoneBox()),
                    ],
                  ),
                  domain: const SpikeCandidateDomain(
                    minimum: 1,
                    maximum: 4,
                    step: 1,
                  ),
                  referenceFontSize: 1,
                  counters: counters,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(build());
        final first = _render(tester);
        expect(first.spikeWetCandidate, 1);
        expect(first.spikeWetFits, isTrue);
        final firstEvaluations = counters.candidateEvaluations;

        await tester.pumpWidget(const SizedBox.shrink());
        counters.resetLayoutCounters();
        await tester.pumpWidget(build());
        final second = _render(tester);
        expect(second.spikeWetCandidate, 1);
        expect(second.spikeWetFits, isTrue);
        expect(counters.candidateEvaluations, firstEvaluations);
        debugPrint(
          'SPIKE_NON_MONOTONE candidate=${second.spikeWetCandidate} '
          'fits=${second.spikeWetFits} evaluations=$firstEvaluations',
        );
        // Candidate 3 also fits this fixture, intentionally proving that the
        // logarithmic contract is deterministic and safe, not globally optimal.
      },
    );

    testWidgets(
      'should keep eager replacement lifecycle stable and expose one semantics branch',
      (tester) async {
        final lifecycle = _LifecycleLedger();
        final key = GlobalKey<SpikeEagerReplacementState>();
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            SpikeEagerReplacement(
              key: key,
              text: _LifecycleProbe(
                name: 'text',
                semanticsLabel: 'active text',
                ledger: lifecycle,
              ),
              replacement: _LifecycleProbe(
                name: 'replacement',
                semanticsLabel: 'active replacement',
                ledger: lifecycle,
              ),
            ),
          ),
        );

        expect(lifecycle.inits, <String, int>{'text': 1, 'replacement': 1});
        expect(find.bySemanticsLabel('active text'), findsOneWidget);
        expect(find.bySemanticsLabel('active replacement'), findsNothing);

        key.currentState!.showResult(fits: false);
        await tester.pump();
        expect(find.bySemanticsLabel('active text'), findsNothing);
        expect(find.bySemanticsLabel('active replacement'), findsOneWidget);
        expect(lifecycle.inits, <String, int>{'text': 1, 'replacement': 1});
        expect(lifecycle.disposes, isEmpty);

        key.currentState!.showResult(fits: true);
        await tester.pump();
        expect(find.bySemanticsLabel('active text'), findsOneWidget);
        expect(find.bySemanticsLabel('active replacement'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(lifecycle.disposes, <String, int>{'text': 1, 'replacement': 1});
        semantics.dispose();
      },
    );

    testWidgets(
      'should preserve recognizers child semantics and SelectionArea registration',
      (tester) async {
        final counters = SpikeCounters();
        var taps = 0;
        final recognizer = TapGestureRecognizer()..onTap = () => taps += 1;
        addTearDown(recognizer.dispose);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            SelectionArea(
              child: SpikeAutoParagraph(
                text: TextSpan(
                  style: const TextStyle(fontSize: 20),
                  children: <InlineSpan>[
                    TextSpan(text: 'Tap', recognizer: recognizer),
                    WidgetSpan(
                      child: Semantics(
                        label: 'inline semantic child',
                        button: true,
                        child: SizedBox(width: 12, height: 12),
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
                counters: counters,
              ),
            ),
          ),
        );

        final render = _render(tester);
        expect(render.spikeParagraph.registrar, isNotNull);
        expect(find.bySemanticsLabel('inline semantic child'), findsOneWidget);
        final box = render.spikeParagraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 3),
            )
            .first;
        await tester.tapAt(
          render.spikeParagraph.localToGlobal(box.toRect().center),
        );
        expect(taps, 1);
        semantics.dispose();
      },
    );

    testWidgets(
      'should dispose temporary painters after exceptions and the owned paragraph',
      (tester) async {
        final counters = SpikeCounters();
        var throwNow = false;
        final scaler = _ToggleThrowScaler(() => throwNow);
        await tester.pumpWidget(
          _host(
            SpikeAutoParagraph(
              text: const TextSpan(
                style: TextStyle(fontSize: 20),
                text: 'painter lifecycle',
              ),
              domain: const SpikeCandidateDomain(
                minimum: 10,
                maximum: 20,
                step: 1,
              ),
              referenceFontSize: 20,
              userScaler: scaler,
              counters: counters,
            ),
          ),
        );
        final render = _render(tester);
        render.spikeDryCandidate(render.constraints);
        expect(
          counters.temporaryPaintersDisposed,
          counters.temporaryPaintersCreated,
        );
        debugPrint(
          'SPIKE_PAINTERS created=${counters.temporaryPaintersCreated} '
          'disposed=${counters.temporaryPaintersDisposed}',
        );

        throwNow = true;
        final createdBeforeFailure = counters.temporaryPaintersCreated;
        expect(
          () => render.spikeDryCandidate(render.constraints),
          throwsStateError,
        );
        expect(counters.temporaryPaintersCreated, createdBeforeFailure + 1);
        expect(
          counters.temporaryPaintersDisposed,
          counters.temporaryPaintersCreated,
        );
        debugPrint(
          'SPIKE_PAINTERS_EXCEPTION '
          'created=${counters.temporaryPaintersCreated} '
          'disposed=${counters.temporaryPaintersDisposed}',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        expect(counters.paragraphDisposals, 1);
      },
    );

    testWidgets('should keep all intrinsics finite and dry-pure', (
      tester,
    ) async {
      final counters = SpikeCounters();
      await tester.pumpWidget(
        _host(
          SpikeAutoParagraph(
            text: const TextSpan(
              style: TextStyle(fontSize: 30),
              text: 'intrinsic metrics',
            ),
            domain: const SpikeCandidateDomain(
              minimum: 10,
              maximum: 30,
              step: 1,
            ),
            referenceFontSize: 30,
            counters: counters,
          ),
        ),
      );
      final render = _render(tester);
      counters.publications = 0;
      final values = <double>[
        render.getMinIntrinsicWidth(60),
        render.getMaxIntrinsicWidth(60),
        render.getMinIntrinsicHeight(120),
        render.getMaxIntrinsicHeight(120),
      ];
      expect(values.every((value) => value.isFinite && value >= 0), isTrue);
      expect(counters.publications, 0);
      expect(
        counters.temporaryPaintersDisposed,
        counters.temporaryPaintersCreated,
      );
    });

    testWidgets(
      'should prove a lazy LayoutBuilder branch cannot answer dry layout',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          _host(
            LayoutBuilder(
              key: key,
              builder: (context, constraints) => constraints.maxWidth >= 100
                  ? const SizedBox(width: 120, height: 70)
                  : const SizedBox(width: 30, height: 40),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(find.byKey(key));
        expect(
          () => render.getDryLayout(const BoxConstraints(maxWidth: 50)),
          throwsFlutterError,
        );
        // Flutter does not guarantee that this RenderObject is reusable after
        // its debugCannotComputeDryLayout error has been intercepted.
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

RenderBox _render(WidgetTester tester) {
  return tester.renderObject<RenderBox>(find.byType(SpikeAutoParagraph));
}

double? renderWetCandidate(WidgetTester tester) =>
    _render(tester).spikeWetCandidate;

double? renderConfiguredCandidate(WidgetTester tester) =>
    _render(tester).spikeConfiguredCandidate;

@immutable
final class _QuadraticScaler extends TextScaler {
  const _QuadraticScaler();

  @override
  double scale(double fontSize) => fontSize + fontSize * fontSize / 100;

  @override
  double get textScaleFactor => 1;
}

final class _ToggleThrowScaler extends TextScaler {
  const _ToggleThrowScaler(this._shouldThrow);

  final bool Function() _shouldThrow;

  @override
  double scale(double fontSize) {
    if (_shouldThrow()) {
      throw StateError('intentional dry scaler failure');
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

final class _LifecycleLedger {
  final inits = <String, int>{};
  final disposes = <String, int>{};
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    required this.name,
    required this.semanticsLabel,
    required this.ledger,
  });

  final String name;
  final String semanticsLabel;
  final _LifecycleLedger ledger;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.ledger.inits.update(
      widget.name,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  void dispose() {
    widget.ledger.disposes.update(
      widget.name,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: const SizedBox(width: 20, height: 20),
    );
  }
}

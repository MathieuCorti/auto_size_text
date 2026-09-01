import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ThrowingTextScaler extends TextScaler {
  const _ThrowingTextScaler(this.error);

  final Object error;

  @override
  double scale(double fontSize) => throw error;

  @override
  double get textScaleFactor => 1;
}

void main() {
  group('AutoSizeText render object', () {
    testWidgets(
      'should never build or query overflowReplacement from dry paths',
      (tester) async {
        final autoKey = GlobalKey();
        final textKey = GlobalKey();
        final replacementKey = GlobalKey();
        late StateSetter setHostState;
        var width = 300.0;
        var replacementBuilds = 0;

        await tester.pumpWidget(
          _host(
            Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setHostState = setState;
                  return SizedBox(
                    width: width,
                    height: 50,
                    child: AutoSizeText(
                      'MMMMMMMMMM',
                      key: autoKey,
                      textKey: textKey,
                      style: const TextStyle(fontSize: 20),
                      minFontSize: 10,
                      maxFontSize: 20,
                      maxLines: 1,
                      softWrap: false,
                      overflowReplacement: LayoutBuilder(
                        builder: (context, constraints) {
                          replacementBuilds += 1;
                          return _WetOnlyBox(
                            key: replacementKey,
                            child: const SizedBox(width: 30, height: 40),
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

        final render = tester.renderObject<RenderBox>(find.byKey(autoKey));
        expect(replacementBuilds, 0);
        expect(find.byKey(replacementKey), findsNothing);
        const narrow = BoxConstraints(maxWidth: 40, maxHeight: 30);
        final beforeWet = <Object?>[
          render.getDryLayout(narrow),
          render.getDryBaseline(narrow, TextBaseline.alphabetic),
          render.getMinIntrinsicWidth(30),
          render.getMaxIntrinsicWidth(30),
          render.getMinIntrinsicHeight(40),
          render.getMaxIntrinsicHeight(40),
        ];
        expect(replacementBuilds, 0);
        expect(find.byKey(replacementKey), findsNothing);

        setHostState(() => width = 40);
        await tester.pump();
        expect(find.byKey(replacementKey), findsOneWidget);
        expect(find.byKey(textKey), findsNothing);
        expect(replacementBuilds, 1);
        final buildsAfterWet = replacementBuilds;

        final afterWet = <Object?>[
          render.getDryLayout(narrow),
          render.getDryBaseline(narrow, TextBaseline.alphabetic),
          render.getMinIntrinsicWidth(30),
          render.getMaxIntrinsicWidth(30),
          render.getMinIntrinsicHeight(40),
          render.getMaxIntrinsicHeight(40),
        ];
        expect(afterWet, beforeWet);
        expect(replacementBuilds, buildsAfterWet);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'should keep replacement state strictly lazy across fit flips',
      (tester) async {
        final ledger = _LifecycleLedger();
        late StateSetter setHostState;
        var width = 300.0;

        await tester.pumpWidget(
          _host(
            Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setHostState = setState;
                  return SizedBox(
                    width: width,
                    height: 40,
                    child: AutoSizeText(
                      'MMMMMMMMMM',
                      style: const TextStyle(fontSize: 20),
                      minFontSize: 10,
                      maxFontSize: 20,
                      maxLines: 1,
                      softWrap: false,
                      overflowReplacement: _LifecycleProbe(ledger: ledger),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(ledger.inits, 0);
        expect(ledger.disposes, 0);
        setHostState(() => width = 30);
        await tester.pump();
        expect(ledger.inits, 1);
        expect(ledger.disposes, 0);
        setHostState(() => width = 300);
        await tester.pump();
        expect(ledger.inits, 1);
        expect(ledger.disposes, 1);
        setHostState(() => width = 30);
        await tester.pump();
        expect(ledger.inits, 2);
        expect(ledger.disposes, 1);
      },
    );

    testWidgets('should make textKey resolve to the rendered paragraph', (
      tester,
    ) async {
      final textKey = GlobalKey();
      await tester.pumpWidget(
        _host(
          AutoSizeText.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Tap '),
                TextSpan(
                  text: 'here',
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
              ],
            ),
            textKey: textKey,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );

      expect(tester.renderObject(find.byKey(textKey)), isA<RenderParagraph>());
      expect(tester.widget(find.byKey(textKey)), isNot(isA<Text>()));
    });

    testWidgets(
      'should preserve recognizers semantics and SelectionArea delegation',
      (tester) async {
        var taps = 0;
        final textKey = GlobalKey();
        final recognizer = TapGestureRecognizer()..onTap = () => taps += 1;
        addTearDown(recognizer.dispose);
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          _host(
            SelectionArea(
              child: AutoSizeText.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(text: 'Selectable '),
                    TextSpan(text: 'action', recognizer: recognizer),
                  ],
                ),
                semanticsLabel: 'Selectable action label',
                textKey: textKey,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );

        expect(
          find.bySemanticsLabel('Selectable action label'),
          findsOneWidget,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(textKey),
        );
        final actionBox = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 11, extentOffset: 17),
            )
            .single;
        await tester.tapAt(paragraph.localToGlobal(actionBox.toRect().center));
        await tester.pump();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    testWidgets('should keep grouped dry queries pure and converge in wet', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      final firstKey = GlobalKey();
      final secondKey = GlobalKey();
      await tester.pumpWidget(
        _host(
          Row(
            children: <Widget>[
              Expanded(
                child: AutoSizeText(
                  'short',
                  key: firstKey,
                  group: group,
                  style: const TextStyle(fontSize: 30),
                  minFontSize: 10,
                ),
              ),
              SizedBox(
                width: 70,
                child: AutoSizeText(
                  'a much longer label',
                  key: secondKey,
                  group: group,
                  style: const TextStyle(fontSize: 30),
                  minFontSize: 10,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.renderObject<RenderBox>(find.byKey(firstKey));
      final second = tester.renderObject<RenderBox>(find.byKey(secondKey));
      const constraints = BoxConstraints(maxWidth: 90, maxHeight: 50);
      final before = <Size>[
        first.getDryLayout(constraints),
        second.getDryLayout(constraints),
      ];
      final repeated = <Size>[
        first.getDryLayout(constraints),
        second.getDryLayout(constraints),
      ];
      expect(repeated, before);
      await tester.idle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump();
      expect(first.getDryLayout(constraints), first.getDryLayout(constraints));
      expect(tester.takeException(), isNull);
    });

    testWidgets('should recover every dry metric after a user scaler failure', (
      tester,
    ) async {
      final key = GlobalKey();
      late StateSetter rebuild;
      TextScaler scaler = TextScaler.noScaling;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AutoSizeText(
                'Recoverable dry metrics',
                key: key,
                style: const TextStyle(fontSize: 24),
                minFontSize: 8,
                maxLines: 1,
                textScaler: scaler,
              );
            },
          ),
        ),
      );

      final render = tester.renderObject<RenderBox>(find.byKey(key));
      const constraints = BoxConstraints(
        minWidth: 11,
        maxWidth: 180,
        minHeight: 7,
        maxHeight: 60,
      );
      final metrics = <Object? Function()>[
        () => render.getDryLayout(constraints),
        () => render.getDryBaseline(constraints, TextBaseline.alphabetic),
        () => render.getMinIntrinsicWidth(60),
        () => render.getMaxIntrinsicWidth(60),
        () => render.getMinIntrinsicHeight(180),
        () => render.getMaxIntrinsicHeight(180),
      ];
      final validMetrics = metrics.map((metric) => metric()).toList();
      final fallbacks = <Object?>[
        constraints.constrain(Size.zero),
        null,
        0.0,
        0.0,
        0.0,
        0.0,
      ];

      for (var index = 0; index < metrics.length; index += 1) {
        final original = StateError('scaler failure $index');
        rebuild(() => scaler = _ThrowingTextScaler(original));
        await tester.pump(null, EnginePhase.build);
        expect(tester.renderObject<RenderBox>(find.byKey(key)), same(render));

        expect(metrics[index](), fallbacks[index]);
        expect(tester.takeException(), same(original));
        expect(tester.takeException(), isNull);

        rebuild(() => scaler = TextScaler.noScaling);
        await tester.pump(null, EnginePhase.build);
        expect(tester.renderObject<RenderBox>(find.byKey(key)), same(render));
        expect(metrics[index](), validMetrics[index]);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('should preserve the original user scaler failure during wet', (
      tester,
    ) async {
      final original = StateError('wet scaler failure');
      late StateSetter rebuild;
      TextScaler scaler = TextScaler.noScaling;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AutoSizeText(
                'Wet failure',
                style: const TextStyle(fontSize: 24),
                textScaler: scaler,
              );
            },
          ),
        ),
      );

      rebuild(() => scaler = _ThrowingTextScaler(original));
      await tester.pump();

      expect(tester.takeException(), same(original));
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

final class _LifecycleLedger {
  int inits = 0;
  int disposes = 0;
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.ledger});

  final _LifecycleLedger ledger;

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
  Widget build(BuildContext context) {
    return const SizedBox(width: 24, height: 32);
  }
}

class _WetOnlyBox extends SingleChildRenderObjectWidget {
  const _WetOnlyBox({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWetOnlyBox();
}

class _RenderWetOnlyBox extends RenderProxyBox {
  Never _reject(String metric) {
    throw FlutterError('_WetOnlyBox rejects $metric.');
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _reject('dry layout');

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    return _reject('dry baseline');
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _reject('minimum intrinsic width');
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _reject('maximum intrinsic width');
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _reject('minimum intrinsic height');
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _reject('maximum intrinsic height');
  }
}

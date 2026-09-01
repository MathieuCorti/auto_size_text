import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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
  double get textScaleFactor => 1;
}

void main() {
  group('AutoSizeText intrinsics', () {
    testWidgets('should support IntrinsicWidth (#28)', (tester) async {
      await tester.pumpWidget(
        _host(
          const Center(
            child: IntrinsicWidth(
              child: AutoSizeText(
                'Intrinsic width',
                minFontSize: 10,
                maxFontSize: 24,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Intrinsic width'), findsOneWidget);
    });

    testWidgets(
      'should support IntrinsicHeight in a list card row (#30, #37)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 320,
              height: 200,
              child: ListView(
                children: const <Widget>[
                  Card(
                    child: IntrinsicHeight(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: AutoSizeText(
                              'A list row whose height is intrinsic',
                              minFontSize: 10,
                              maxFontSize: 30,
                              maxLines: 2,
                            ),
                          ),
                          VerticalDivider(),
                          SizedBox(width: 24, height: 48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Card), findsOneWidget);
      },
    );

    testWidgets('should support Chip and FilterChip labels (#77)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: Wrap(
              children: <Widget>[
                const Chip(
                  label: AutoSizeText(
                    'Chip label',
                    minFontSize: 10,
                    maxFontSize: 18,
                  ),
                ),
                FilterChip(
                  label: const AutoSizeText.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: 'Filter '),
                        TextSpan(
                          text: 'label',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    minFontSize: 10,
                    maxFontSize: 18,
                  ),
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(FilterChip), findsOneWidget);
    });

    testWidgets('should support DataTable cells (#129)', (tester) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: AutoSizeText('Name')),
                DataColumn(label: AutoSizeText('Value')),
              ],
              rows: const <DataRow>[
                DataRow(
                  cells: <DataCell>[
                    DataCell(AutoSizeText('A long table cell')),
                    DataCell(AutoSizeText('42')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('should support PaginatedDataTable cells (#147)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: PaginatedDataTable(
              header: const AutoSizeText('Paged values'),
              rowsPerPage: 1,
              columns: const <DataColumn>[
                DataColumn(label: AutoSizeText('Name')),
                DataColumn(label: AutoSizeText('Value')),
              ],
              source: _SingleRowSource(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PaginatedDataTable), findsOneWidget);
    });

    testWidgets(
      'should match RenderParagraph direct intrinsic and dry metrics',
      (tester) async {
        final autoKey = GlobalKey();
        final witnessKey = GlobalKey();
        const style = TextStyle(fontSize: 20);

        await tester.pumpWidget(
          _host(
            Row(
              children: <Widget>[
                Expanded(
                  child: AutoSizeText(
                    'Exact paragraph metrics',
                    key: autoKey,
                    style: style,
                    minFontSize: 20,
                    maxFontSize: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Exact paragraph metrics',
                    key: witnessKey,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        );

        final auto = tester.renderObject<RenderBox>(find.byKey(autoKey));
        final witness = tester.renderObject<RenderParagraph>(
          find.byKey(witnessKey),
        );
        const dryConstraints = BoxConstraints(
          minWidth: 24,
          maxWidth: 180,
          minHeight: 12,
          maxHeight: 80,
        );

        expect(
          auto.getDryLayout(dryConstraints),
          witness.getDryLayout(dryConstraints),
        );
        expect(
          auto.getDryBaseline(dryConstraints, TextBaseline.alphabetic),
          moreOrLessEquals(
            witness.getDryBaseline(dryConstraints, TextBaseline.alphabetic)!,
            epsilon: 0.001,
          ),
        );
        expect(
          auto.getDryBaseline(dryConstraints, TextBaseline.ideographic),
          moreOrLessEquals(
            witness.getDryBaseline(dryConstraints, TextBaseline.ideographic)!,
            epsilon: 0.001,
          ),
        );
        expect(auto.getMinIntrinsicWidth(80), witness.getMinIntrinsicWidth(80));
        expect(auto.getMaxIntrinsicWidth(80), witness.getMaxIntrinsicWidth(80));
        expect(
          auto.getMinIntrinsicHeight(180),
          witness.getMinIntrinsicHeight(180),
        );
        expect(
          auto.getMaxIntrinsicHeight(180),
          witness.getMaxIntrinsicHeight(180),
        );
      },
    );

    testWidgets(
      'should use the minimum paragraph metrics when no candidate fits',
      (tester) async {
        final autoKey = GlobalKey();
        final textKey = GlobalKey();
        final witnessKey = GlobalKey();
        const tight = BoxConstraints.tightFor(width: 5, height: 8);

        await tester.pumpWidget(
          _host(
            Column(
              children: <Widget>[
                ConstrainedBox(
                  constraints: tight,
                  child: AutoSizeText(
                    'MMMM',
                    key: autoKey,
                    textKey: textKey,
                    style: const TextStyle(fontSize: 20),
                    minFontSize: 10,
                    maxFontSize: 20,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                ConstrainedBox(
                  constraints: tight,
                  child: Text(
                    'MMMM',
                    key: witnessKey,
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        );

        final auto = tester.renderObject<RenderBox>(find.byKey(autoKey));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(textKey),
        );
        final witness = tester.renderObject<RenderParagraph>(
          find.byKey(witnessKey),
        );
        expect(paragraph.textScaler.scale(20), 10);
        expect(auto.size, witness.size);
        expect(auto.getDryLayout(tight), witness.getDryLayout(tight));
        for (final baseline in TextBaseline.values) {
          expect(
            auto.getDryBaseline(tight, baseline),
            moreOrLessEquals(
              witness.getDryBaseline(tight, baseline)!,
              epsilon: 0.001,
            ),
          );
        }
      },
    );

    testWidgets('should keep simple and rich dry search logarithmic', (
      tester,
    ) async {
      final simpleKey = GlobalKey();
      final richKey = GlobalKey();
      final simpleCounter = _ScaleCounter();
      final richCounter = _ScaleCounter();

      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              AutoSizeText(
                'MMMM',
                key: simpleKey,
                style: const TextStyle(fontSize: 1000000),
                minFontSize: 1,
                stepGranularity: 0.1,
                maxLines: 1,
                textScaler: _CountingIdentityTextScaler(simpleCounter),
              ),
              AutoSizeText.rich(
                const TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: 'MM'),
                    TextSpan(
                      text: 'MM',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                key: richKey,
                style: const TextStyle(fontSize: 1000000),
                minFontSize: 1,
                stepGranularity: 0.1,
                maxLines: 1,
                textScaler: _CountingIdentityTextScaler(richCounter),
              ),
            ],
          ),
        ),
      );

      simpleCounter.calls = 0;
      richCounter.calls = 0;
      const dry = BoxConstraints.tightFor(width: 1, height: 1);
      tester.renderObject<RenderBox>(find.byKey(simpleKey)).getDryLayout(dry);
      tester.renderObject<RenderBox>(find.byKey(richKey)).getDryLayout(dry);

      expect(simpleCounter.calls, inInclusiveRange(1, 120));
      expect(richCounter.calls, inInclusiveRange(1, 200));
    });

    testWidgets(
      'should keep repeated dry metrics finite with infinite axes and minima',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          _host(
            AutoSizeText.rich(
              const TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'Rich '),
                  TextSpan(text: 'intrinsics', style: TextStyle(fontSize: 28)),
                ],
              ),
              key: key,
              style: const TextStyle(fontSize: 24),
              minFontSize: 8,
              maxFontSize: 24,
              presetFontSizes: const <double>[24, 16, 8],
              maxLines: 2,
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(find.byKey(key));
        const constraints = <BoxConstraints>[
          BoxConstraints(minWidth: 30, maxWidth: 140, minHeight: 10),
          BoxConstraints(maxWidth: double.infinity, maxHeight: 60),
          BoxConstraints(maxWidth: 140, maxHeight: double.infinity),
        ];
        for (final value in constraints) {
          final first = render.getDryLayout(value);
          final second = render.getDryLayout(value);
          expect(second, first);
          expect(first.width.isFinite && first.height.isFinite, isTrue);
          final baseline = render.getDryBaseline(
            value,
            TextBaseline.alphabetic,
          );
          expect(baseline?.isFinite, isTrue);
        }
        final intrinsics = <double>[
          render.getMinIntrinsicWidth(double.infinity),
          render.getMaxIntrinsicWidth(double.infinity),
          render.getMinIntrinsicHeight(double.infinity),
          render.getMaxIntrinsicHeight(double.infinity),
        ];
        expect(intrinsics.every((value) => value.isFinite), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

final class _SingleRowSource extends DataTableSource {
  @override
  DataRow? getRow(int index) {
    if (index != 0) {
      return null;
    }
    return DataRow.byIndex(
      index: 0,
      cells: const <DataCell>[
        DataCell(AutoSizeText('Paged row')),
        DataCell(AutoSizeText('7')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => 1;

  @override
  int get selectedRowCount => 0;
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _groupHost(AutoSizeGroup group, List<MapEntry<String, int>> reports) {
  return MaterialApp(
    home: Column(
      children: reports.map((entry) {
        final report = entry.value;
        return AutoSizeText(
          '',
          key: ValueKey<String>('widget-${entry.key}'),
          textKey: ValueKey<String>('text-${entry.key}'),
          style: TextStyle(fontSize: report.toDouble()),
          presetFontSizes: <double>[
            for (var candidate = report; candidate >= 10; candidate -= 10)
              candidate.toDouble(),
          ],
          textScaler: TextScaler.noScaling,
          group: group,
        );
      }).toList(),
    ),
  );
}

Future<void> _pumpReports(
  WidgetTester tester,
  AutoSizeGroup group,
  List<MapEntry<String, int>> reports,
) async {
  await tester.pumpWidget(_groupHost(group, reports));
  await tester.pump();
}

void _expectSizes(
  WidgetTester tester,
  List<MapEntry<String, int>> reports,
  List<double> expected,
) {
  final actual = reports.map((entry) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(ValueKey<String>('text-${entry.key}')),
    );
    return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
  });
  expect(actual, orderedEquals(expected));
}

void main() {
  group('AutoSizeGroup minimum maintenance', () {
    testWidgets(
      'should converge after ascending and descending first publications',
      (tester) async {
        for (final reports in <List<MapEntry<String, int>>>[
          const <MapEntry<String, int>>[
            MapEntry<String, int>('ascending-a', 20),
            MapEntry<String, int>('ascending-b', 30),
            MapEntry<String, int>('ascending-c', 40),
          ],
          const <MapEntry<String, int>>[
            MapEntry<String, int>('descending-a', 40),
            MapEntry<String, int>('descending-b', 30),
            MapEntry<String, int>('descending-c', 20),
          ],
        ]) {
          final group = AutoSizeGroup();
          await _pumpReports(tester, group, reports);

          _expectSizes(tester, reports, const <double>[20, 20, 20]);
          expect(tester.binding.hasScheduledFrame, isFalse);
        }
      },
    );

    testWidgets('should lower the limit when any report decreases', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      var reports = const <MapEntry<String, int>>[
        MapEntry<String, int>('decrease-a', 20),
        MapEntry<String, int>('decrease-b', 30),
        MapEntry<String, int>('decrease-c', 40),
      ];
      await _pumpReports(tester, group, reports);
      _expectSizes(tester, reports, const <double>[20, 20, 20]);

      reports = const <MapEntry<String, int>>[
        MapEntry<String, int>('decrease-a', 20),
        MapEntry<String, int>('decrease-b', 30),
        MapEntry<String, int>('decrease-c', 10),
      ];
      await _pumpReports(tester, group, reports);

      _expectSizes(tester, reports, const <double>[10, 10, 10]);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'should retain an increased non-minimum report until it becomes minimum',
      (tester) async {
        final group = AutoSizeGroup();
        var reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('non-min-a', 20),
          MapEntry<String, int>('non-min-b', 30),
          MapEntry<String, int>('non-min-c', 40),
        ];
        await _pumpReports(tester, group, reports);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('non-min-a', 20),
          MapEntry<String, int>('non-min-b', 30),
          MapEntry<String, int>('non-min-c', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[20, 20, 20]);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('non-min-b', 30),
          MapEntry<String, int>('non-min-c', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[30, 30]);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('non-min-c', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[50]);
      },
    );

    testWidgets('should rescan when the minimum report increases', (
      tester,
    ) async {
      final group = AutoSizeGroup();
      var reports = const <MapEntry<String, int>>[
        MapEntry<String, int>('increase-min-a', 20),
        MapEntry<String, int>('increase-min-b', 30),
        MapEntry<String, int>('increase-min-c', 40),
      ];
      await _pumpReports(tester, group, reports);

      reports = const <MapEntry<String, int>>[
        MapEntry<String, int>('increase-min-a', 40),
        MapEntry<String, int>('increase-min-b', 30),
        MapEntry<String, int>('increase-min-c', 40),
      ];
      await _pumpReports(tester, group, reports);

      _expectSizes(tester, reports, const <double>[30, 30, 30]);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'should preserve ties and delete minimum and non-minimum reports',
      (tester) async {
        final group = AutoSizeGroup();
        var reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('ties-a', 20),
          MapEntry<String, int>('ties-b', 20),
          MapEntry<String, int>('ties-c', 40),
          MapEntry<String, int>('ties-d', 50),
        ];
        await _pumpReports(tester, group, reports);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('ties-a', 30),
          MapEntry<String, int>('ties-b', 20),
          MapEntry<String, int>('ties-c', 40),
          MapEntry<String, int>('ties-d', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[20, 20, 20, 20]);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('ties-a', 30),
          MapEntry<String, int>('ties-b', 20),
          MapEntry<String, int>('ties-d', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[20, 20, 20]);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('ties-a', 30),
          MapEntry<String, int>('ties-d', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[30, 30]);

        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('ties-d', 50),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[50]);

        await _pumpReports(tester, group, const <MapEntry<String, int>>[]);
        reports = const <MapEntry<String, int>>[
          MapEntry<String, int>('after-empty', 60),
        ];
        await _pumpReports(tester, group, reports);
        _expectSizes(tester, reports, const <double>[60]);
      },
    );
  });
}

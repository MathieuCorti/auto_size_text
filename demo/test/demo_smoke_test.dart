import 'package:auto_size_text/auto_size_text.dart';
import 'package:demo/main.dart';
import 'package:demo/max_lines_demo.dart';
import 'package:demo/min_font_size_demo.dart';
import 'package:demo/overflow_replacement_demo.dart';
import 'package:demo/preset_font_sizes_demo.dart';
import 'package:demo/step_granularity.dart';
import 'package:demo/sync_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoApp', () {
    testWidgets('should expose and open all six demo destinations', (
      tester,
    ) async {
      await _pumpDemo(tester);

      expect(find.byType(NavigationDestination), findsNWidgets(6));

      final destinations = <({String label, String title, Type widgetType})>[
        (label: 'maxLines', title: 'MaxLines', widgetType: MaxlinesDemo),
        (
          label: 'minFontSize',
          title: 'MinFontSize',
          widgetType: MinFontSizeDemo,
        ),
        (label: 'group', title: 'Group', widgetType: SyncDemo),
        (
          label: 'granularity',
          title: 'StepGranularity',
          widgetType: StepGranularityDemo,
        ),
        (
          label: 'preset',
          title: 'PresetFontSizes',
          widgetType: PresetFontSizesDemo,
        ),
        (
          label: 'replacement',
          title: 'OverflowReplacement',
          widgetType: OverflowReplacementDemo,
        ),
      ];

      for (final destination in destinations) {
        await tester.tap(find.text(destination.label));
        await tester.pump();

        expect(find.byType(destination.widgetType), findsOneWidget);
        expect(find.text('AutoSizeText: ${destination.title}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('should switch between normal and rich text demos', (
      tester,
    ) async {
      await _pumpDemo(tester);

      final normalText = tester.widget<AutoSizeText>(find.byType(AutoSizeText));
      expect(find.text('Normal Text'), findsOneWidget);
      expect(normalText.data, isNotNull);
      expect(normalText.textSpan, isNull);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final richText = tester.widget<AutoSizeText>(find.byType(AutoSizeText));
      expect(find.text('Rich Text'), findsOneWidget);
      expect(richText.data, isNull);
      expect(richText.textSpan, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncDemo', () {
    testWidgets('should keep one group while the layout animation advances', (
      tester,
    ) async {
      await _setLandscapeSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SyncDemo(false))),
      );
      await tester.pump();

      final initialTexts = tester
          .widgetList<AutoSizeText>(find.byType(AutoSizeText))
          .toList();
      final initialGroup = initialTexts.first.group;
      final initialFlex = tester.widget<Flexible>(
        find.byKey(const ValueKey<String>('sync-resizing-text')),
      );

      expect(initialTexts, hasLength(2));
      expect(initialGroup, isNotNull);
      expect(
        initialTexts.every((text) => identical(text.group, initialGroup)),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 1));

      final animatedTexts = tester
          .widgetList<AutoSizeText>(find.byType(AutoSizeText))
          .toList();
      final animatedFlex = tester.widget<Flexible>(
        find.byKey(const ValueKey<String>('sync-resizing-text')),
      );
      expect(animatedFlex.flex, greaterThan(initialFlex.flex));
      expect(
        animatedTexts.every((text) => identical(text.group, initialGroup)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('should not restart the animation after dispose', (
      tester,
    ) async {
      await _setLandscapeSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SyncDemo(false))),
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3, milliseconds: 1));

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpDemo(WidgetTester tester) async {
  await _setLandscapeSurface(tester);
  await tester.pumpWidget(const App());
  await tester.pump();
}

Future<void> _setLandscapeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

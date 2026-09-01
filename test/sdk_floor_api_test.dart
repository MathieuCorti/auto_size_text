import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flutter SDK floor', () {
    testWidgets('should expose MediaQuery text metric overrides', (
      tester,
    ) async {
      const data = MediaQueryData(
        lineHeightScaleFactorOverride: 1.1,
        letterSpacingOverride: 1.2,
        wordSpacingOverride: 1.3,
      );

      late BuildContext context;
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        data.lineHeightScaleFactorOverride,
      );
      expect(
        MediaQuery.maybeLetterSpacingOverrideOf(context),
        data.letterSpacingOverride,
      );
      expect(
        MediaQuery.maybeWordSpacingOverrideOf(context),
        data.wordSpacingOverride,
      );
    });
  });
}

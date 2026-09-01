import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils.dart';

void main() {
  group('AutoSizeText', () {
    testWidgets('should show overflow replacement on overflow', (tester) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: SizedBox(
          width: 100,
          height: 20,
          child: AutoSizeText(
            'XXXXXX',
            overflowReplacement: Text('OVERFLOW!'),
            minFontSize: 20,
          ),
        ),
      );
      expect(text.data, 'OVERFLOW!');
    });

    testWidgets('should hide overflow replacement without overflow', (
      tester,
    ) async {
      final text = await pumpAndGetText(
        tester: tester,
        widget: SizedBox(
          width: 100,
          height: 20,
          child: AutoSizeText(
            'XXXXX',
            style: TextStyle(fontSize: 20),
            overflowReplacement: Text('OVERFLOW!'),
          ),
        ),
      );
      expect(text.data, 'XXXXX');
    });
  });
}

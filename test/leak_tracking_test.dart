import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'leak_tracking.dart';

void main() {
  group('Native resource leak tracking', () {
    testWidgets('should accept a disposed TextPainter', (tester) async {
      final painter = TextPainter(textDirection: TextDirection.ltr)
        ..text = const TextSpan(text: 'tracked')
        ..layout();

      painter.dispose();
    }, experimentalLeakTesting: nativeResourceLeakTesting);
  });
}

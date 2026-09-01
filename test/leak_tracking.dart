import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Tracks instrumented Flutter resources that are not disposed by a test.
final nativeResourceLeakTesting = LeakTesting.settings
    .withTrackedAll()
    .withTracked(allNotDisposed: true)
    .withCreationStackTrace();

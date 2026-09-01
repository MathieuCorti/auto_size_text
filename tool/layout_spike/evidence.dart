import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lifecycle and render counters for the lazy replacement witness.
final class EvidenceBranchLedger {
  final Map<String, int> inits = <String, int>{};
  final Map<String, int> disposes = <String, int>{};
  final Map<String, int> wetLayouts = <String, int>{};
  final Map<String, int> dryLayouts = <String, int>{};
  final Map<String, int> paints = <String, int>{};
  final Map<String, int> hitTests = <String, int>{};
  final Map<String, int> taps = <String, int>{};

  void increment(Map<String, int> counter, String name) {
    counter.update(name, (value) => value + 1, ifAbsent: () => 1);
  }
}

/// A lazy branch switcher whose dry path can only see the mounted branch.
class EvidenceLazySwitch extends ConstrainedLayoutBuilder<BoxConstraints> {
  EvidenceLazySwitch({super.key, required EvidenceBranchLedger ledger})
    : super(
        builder: (context, constraints) {
          final showText = constraints.maxWidth >= 100;
          return EvidenceBranch(
            key: ValueKey<String>(
              showText ? 'text-state' : 'replacement-state',
            ),
            name: showText ? 'text' : 'replacement',
            semanticsLabel: showText ? 'text branch' : 'replacement branch',
            preferredSize: showText ? const Size(120, 70) : const Size(30, 40),
            ledger: ledger,
          );
        },
      );

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox>
  createRenderObject(BuildContext context) => _EvidenceRenderLazySwitch();
}

class _EvidenceRenderLazySwitch extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(child?.getDryLayout(constraints) ?? Size.zero);
  }

  @override
  void performLayout() {
    runLayoutCallback();
    final renderChild = child;
    if (renderChild == null) {
      size = constraints.smallest;
      return;
    }
    renderChild.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(renderChild.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final renderChild = child;
    if (renderChild != null) {
      context.paintChild(renderChild, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position) ?? false;
  }
}

/// A stateful, semantic and interactive fixed-size replacement branch.
class EvidenceBranch extends StatefulWidget {
  const EvidenceBranch({
    super.key,
    required this.name,
    required this.semanticsLabel,
    required this.preferredSize,
    required this.ledger,
  });

  final String name;
  final String semanticsLabel;
  final Size preferredSize;
  final EvidenceBranchLedger ledger;

  @override
  State<EvidenceBranch> createState() => _EvidenceBranchState();
}

class _EvidenceBranchState extends State<EvidenceBranch> {
  @override
  void initState() {
    super.initState();
    widget.ledger.increment(widget.ledger.inits, widget.name);
  }

  @override
  void dispose() {
    widget.ledger.increment(widget.ledger.disposes, widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.ledger.increment(widget.ledger.taps, widget.name),
        child: _EvidenceFixedBox(
          name: widget.name,
          preferredSize: widget.preferredSize,
          ledger: widget.ledger,
        ),
      ),
    );
  }
}

class _EvidenceFixedBox extends LeafRenderObjectWidget {
  const _EvidenceFixedBox({
    required this.name,
    required this.preferredSize,
    required this.ledger,
  });

  final String name;
  final Size preferredSize;
  final EvidenceBranchLedger ledger;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceRenderFixedBox(name, preferredSize, ledger);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _EvidenceRenderFixedBox renderObject,
  ) {
    renderObject
      ..name = name
      ..preferredSize = preferredSize
      ..ledger = ledger;
  }
}

class _EvidenceRenderFixedBox extends RenderBox {
  _EvidenceRenderFixedBox(this.name, this.preferredSize, this.ledger);

  String name;
  Size preferredSize;
  EvidenceBranchLedger ledger;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    ledger.increment(ledger.dryLayouts, name);
    return constraints.constrain(preferredSize);
  }

  @override
  void performLayout() {
    ledger.increment(ledger.wetLayouts, name);
    size = constraints.constrain(preferredSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    ledger.increment(ledger.paints, name);
    context.canvas.drawRect(
      offset & size,
      Paint()..color = const Color(0xFF336699),
    );
  }

  @override
  bool hitTestSelf(Offset position) {
    ledger.increment(ledger.hitTests, name);
    return true;
  }
}

/// Records which intrinsic and dry APIs an inline child receives.
final class EvidenceIntrinsicCounters {
  int minWidths = 0;
  int maxWidths = 0;
  int minHeights = 0;
  int maxHeights = 0;
  int dryLayouts = 0;
  int wetLayouts = 0;

  void reset() {
    minWidths = 0;
    maxWidths = 0;
    minHeights = 0;
    maxHeights = 0;
    dryLayouts = 0;
    wetLayouts = 0;
  }
}

/// A child with deliberately distinct intrinsic and dry dimensions.
class EvidenceIntrinsicBox extends LeafRenderObjectWidget {
  const EvidenceIntrinsicBox({super.key, required this.counters});

  final EvidenceIntrinsicCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceRenderIntrinsicBox(counters);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _EvidenceRenderIntrinsicBox).counters = counters;
  }
}

class _EvidenceRenderIntrinsicBox extends RenderBox {
  _EvidenceRenderIntrinsicBox(this.counters);

  EvidenceIntrinsicCounters counters;

  @override
  double computeMinIntrinsicWidth(double height) {
    counters.minWidths += 1;
    return 11;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    counters.maxWidths += 1;
    return 37;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    counters.minHeights += 1;
    return 13;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    counters.maxHeights += 1;
    return 29;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    counters.dryLayouts += 1;
    return constraints.constrain(const Size(23, 17));
  }

  @override
  void performLayout() {
    counters.wetLayouts += 1;
    size = constraints.constrain(const Size(23, 17));
  }
}

/// A child that has dry size but deliberately lacks a dry baseline.
class EvidenceNoDryBaselineBox extends LeafRenderObjectWidget {
  const EvidenceNoDryBaselineBox({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceRenderNoDryBaselineBox();
  }
}

class _EvidenceRenderNoDryBaselineBox extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(10, 12));
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 12));
  }
}

/// A child with an explicit dry and wet alphabetic baseline.
class EvidenceDryBaselineBox extends LeafRenderObjectWidget {
  const EvidenceDryBaselineBox({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceRenderDryBaselineBox();
  }
}

class _EvidenceRenderDryBaselineBox extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(10, 12));
  }

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    return 6;
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(10, 12));
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) => 6;
}

/// Counters for transformed inline painting and pointer dispatch.
final class EvidenceInteractionCounters {
  int paints = 0;
  int hitTests = 0;
  int pointerDowns = 0;
}

/// A painted and hit-testable inline leaf.
class EvidenceInteractiveBox extends LeafRenderObjectWidget {
  const EvidenceInteractiveBox({super.key, required this.counters});

  final EvidenceInteractionCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceRenderInteractiveBox(counters);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _EvidenceRenderInteractiveBox).counters = counters;
  }
}

class _EvidenceRenderInteractiveBox extends RenderBox {
  _EvidenceRenderInteractiveBox(this.counters);

  EvidenceInteractionCounters counters;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(20, 16));
  }

  @override
  void performLayout() {
    size = constraints.constrain(const Size(20, 16));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    counters.paints += 1;
    context.canvas.drawRect(
      offset & size,
      Paint()..color = const Color(0xFFAA3300),
    );
  }

  @override
  bool hitTestSelf(Offset position) {
    counters.hitTests += 1;
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      counters.pointerDowns += 1;
    }
  }
}

/// Mounts a paragraph that illegally mutates itself during layout.
class EvidenceSelfMutationWidget extends LeafRenderObjectWidget {
  const EvidenceSelfMutationWidget({super.key, required this.recorder});

  final EvidenceMutationRecorder recorder;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceSelfMutatingParagraph(
      const TextSpan(text: 'self mutation'),
      textDirection: TextDirection.ltr,
      recorder: recorder,
    );
  }
}

/// Mounts an ordinary parent that illegally mutates its paragraph child.
class EvidenceParentMutationWidget extends SingleChildRenderObjectWidget {
  const EvidenceParentMutationWidget({
    super.key,
    required this.recorder,
    required super.child,
  });

  final EvidenceMutationRecorder recorder;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _EvidenceMutatingParent(recorder);
  }
}

/// Captures an expected mutation assertion while allowing layout to finish.
final class EvidenceMutationRecorder {
  FlutterError? error;
}

class _EvidenceSelfMutatingParagraph extends RenderParagraph {
  _EvidenceSelfMutatingParagraph(
    super.text, {
    required super.textDirection,
    required this.recorder,
  });

  final EvidenceMutationRecorder recorder;

  @override
  void performLayout() {
    try {
      textScaler = const TextScaler.linear(2);
    } on FlutterError catch (error) {
      recorder.error = error;
    }
    super.performLayout();
  }
}

class _EvidenceMutatingParent extends RenderProxyBox {
  _EvidenceMutatingParent(this.recorder);

  final EvidenceMutationRecorder recorder;

  @override
  void performLayout() {
    final paragraph = child! as RenderParagraph;
    try {
      paragraph.textScaler = const TextScaler.linear(2);
    } on FlutterError catch (error) {
      recorder.error = error;
    }
    paragraph.layout(constraints, parentUsesSize: true);
    size = paragraph.size;
  }
}

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fault injection selected by `--dart-define=SPIKE_MUTANT=<name>`.
const String spikeMutant = String.fromEnvironment('SPIKE_MUTANT');

/// Deterministic counters used by the temporary layout spike.
final class SpikeCounters {
  int candidateEvaluations = 0;
  int paragraphWetLayouts = 0;
  int finalRelayouts = 0;
  int childWetLayouts = 0;
  int childDryQueries = 0;
  int drySelections = 0;
  int publications = 0;
  int outerPerformLayouts = 0;
  int temporaryPaintersCreated = 0;
  int temporaryPaintersDisposed = 0;
  int paragraphDisposals = 0;
  int inlineWrapperDisposals = 0;

  void resetLayoutCounters() {
    candidateEvaluations = 0;
    paragraphWetLayouts = 0;
    finalRelayouts = 0;
    childWetLayouts = 0;
    childDryQueries = 0;
    drySelections = 0;
    publications = 0;
    outerPerformLayouts = 0;
  }
}

/// An immutable, virtual, ascending candidate domain.
@immutable
final class SpikeCandidateDomain {
  const SpikeCandidateDomain({
    required this.minimum,
    required this.maximum,
    required this.step,
  }) : assert(step > 0),
       assert(maximum >= minimum);

  final double minimum;
  final double maximum;
  final double step;

  int get length => ((maximum - minimum) / step).floor() + 1;

  double operator [](int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this);
    }
    return index == length - 1 ? maximum : minimum + index * step;
  }

  SpikeSearchResult findLargestThatFits(bool Function(double) fits) {
    if (spikeMutant == 'linear_search') {
      var best = minimum;
      var found = false;
      for (var index = 0; index < length; index += 1) {
        final candidate = this[index];
        if (fits(candidate)) {
          best = candidate;
          found = true;
        }
      }
      return SpikeSearchResult(best, found);
    }

    var left = 0;
    var right = length - 1;
    var bestIndex = 0;
    var found = false;
    while (left <= right) {
      final middle = left + (right - left) ~/ 2;
      if (fits(this[middle])) {
        bestIndex = middle;
        found = true;
        left = middle + 1;
      } else {
        right = middle - 1;
      }
    }
    return SpikeSearchResult(this[bestIndex], found);
  }
}

@immutable
final class SpikeSearchResult {
  const SpikeSearchResult(this.candidate, this.fits);

  final double candidate;
  final bool fits;
}

/// Candidate composition used by text runs and inline children.
@immutable
final class SpikeCandidateScaler extends TextScaler {
  const SpikeCandidateScaler({
    required this.source,
    required this.candidate,
    required this.reference,
  }) : assert(reference >= 0);

  final TextScaler source;
  final double candidate;
  final double reference;

  @override
  double scale(double fontSize) {
    if (reference == 0) {
      return 0;
    }
    return source.scale(fontSize * candidate / reference);
  }

  @override
  double get textScaleFactor =>
      reference == 0 ? 0 : scale(reference) / reference;

  @override
  bool operator ==(Object other) {
    return other is SpikeCandidateScaler &&
        source == other.source &&
        candidate == other.candidate &&
        reference == other.reference;
  }

  @override
  int get hashCode => Object.hash(source, candidate, reference);
}

/// A temporary widget proving the render/layout boundary.
class SpikeAutoParagraph extends StatelessWidget {
  const SpikeAutoParagraph({
    super.key,
    required this.text,
    required this.domain,
    required this.referenceFontSize,
    required this.counters,
    this.userScaler = TextScaler.noScaling,
    this.groupLimit = double.infinity,
    this.onPublish,
    this.textDirection = TextDirection.ltr,
    this.maxLines,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.selectionColor = const Color(0x6633AAFF),
  });

  final InlineSpan text;
  final SpikeCandidateDomain domain;
  final double referenceFontSize;
  final SpikeCounters counters;
  final TextScaler userScaler;
  final double groupLimit;
  final ValueChanged<double>? onPublish;
  final TextDirection textDirection;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final Color selectionColor;

  @override
  Widget build(BuildContext context) {
    final selectionRegistrar = SelectionContainer.maybeOf(context);
    return _SpikeFitterWidget(
      domain: domain,
      referenceFontSize: referenceFontSize,
      userScaler: userScaler,
      groupLimit: groupLimit,
      counters: counters,
      onPublish: onPublish,
      child: _SpikeParagraphWidget(
        text: text,
        textDirection: textDirection,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
        selectionRegistrar: selectionRegistrar,
        selectionColor: selectionRegistrar == null ? null : selectionColor,
        counters: counters,
      ),
    );
  }
}

/// Eager replacement policy used only to prove lifecycle and semantics.
///
/// Both branches stay mounted; exactly one branch participates in semantics,
/// paint and hit testing. This is the explicit fallback allowed by lot 8.
class SpikeEagerReplacement extends StatefulWidget {
  const SpikeEagerReplacement({
    super.key,
    required this.text,
    required this.replacement,
  });

  final Widget text;
  final Widget replacement;

  @override
  State<SpikeEagerReplacement> createState() => SpikeEagerReplacementState();
}

class SpikeEagerReplacementState extends State<SpikeEagerReplacement> {
  bool _showText = true;

  bool get showText => _showText;

  void showResult({required bool fits}) {
    if (_showText == fits) {
      return;
    }
    setState(() {
      _showText = fits;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Offstage(
          offstage: !_showText,
          child: ExcludeSemantics(excluding: !_showText, child: widget.text),
        ),
        Offstage(
          offstage: _showText,
          child: ExcludeSemantics(
            excluding: _showText,
            child: widget.replacement,
          ),
        ),
      ],
    );
  }
}

class _SpikeFitterWidget extends SingleChildRenderObjectWidget {
  const _SpikeFitterWidget({
    required this.domain,
    required this.referenceFontSize,
    required this.userScaler,
    required this.groupLimit,
    required this.counters,
    required this.onPublish,
    required super.child,
  });

  final SpikeCandidateDomain domain;
  final double referenceFontSize;
  final TextScaler userScaler;
  final double groupLimit;
  final SpikeCounters counters;
  final ValueChanged<double>? onPublish;

  @override
  _SpikeRenderFitter createRenderObject(BuildContext context) {
    return _SpikeRenderFitter(
      domain: domain,
      referenceFontSize: referenceFontSize,
      userScaler: userScaler,
      groupLimit: groupLimit,
      counters: counters,
      onPublish: onPublish,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _SpikeRenderFitter renderObject,
  ) {
    renderObject
      ..domain = domain
      ..referenceFontSize = referenceFontSize
      ..userScaler = userScaler
      ..groupLimit = groupLimit
      ..counters = counters
      ..onPublish = onPublish;
  }
}

class _SpikeParagraphWidget extends MultiChildRenderObjectWidget {
  _SpikeParagraphWidget({
    required this.text,
    required this.textDirection,
    required this.maxLines,
    required this.softWrap,
    required this.overflow,
    required this.selectionRegistrar,
    required this.selectionColor,
    required this.counters,
  }) : super(children: _extractInlineChildren(text, counters));

  final InlineSpan text;
  final TextDirection textDirection;
  final int? maxLines;
  final bool softWrap;
  final TextOverflow overflow;
  final SelectionRegistrar? selectionRegistrar;
  final Color? selectionColor;
  final SpikeCounters counters;

  @override
  _SpikeRenderParagraph createRenderObject(BuildContext context) {
    return _SpikeRenderParagraph(
      text,
      textDirection: textDirection,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      registrar: selectionRegistrar,
      selectionColor: selectionColor,
      counters: counters,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _SpikeRenderParagraph renderObject,
  ) {
    renderObject
      ..text = text
      ..textDirection = textDirection
      ..maxLines = maxLines
      ..softWrap = softWrap
      ..overflow = overflow
      ..registrar = selectionRegistrar
      ..selectionColor = selectionColor
      ..counters = counters;
  }
}

List<Widget> _extractInlineChildren(InlineSpan root, SpikeCounters counters) {
  final widgets = <Widget>[];
  var semanticsIndex = 0;

  void visit(InlineSpan span, double inheritedFontSize) {
    final runFontSize = span.style?.fontSize ?? inheritedFontSize;
    if (span case final WidgetSpan widgetSpan) {
      widgets.add(
        _SpikeInlineParentData(
          span: widgetSpan,
          child: Semantics(
            tagForChildren: PlaceholderSpanIndexSemanticsTag(semanticsIndex++),
            child: _SpikeInlineScale(
              runFontSize: runFontSize,
              counters: counters,
              child: widgetSpan.child,
            ),
          ),
        ),
      );
    }
    span.visitDirectChildren((child) {
      visit(child, runFontSize);
      return true;
    });
  }

  visit(root, root.style?.fontSize ?? kDefaultFontSize);
  return widgets;
}

class _SpikeInlineParentData extends ParentDataWidget<TextParentData> {
  const _SpikeInlineParentData({required this.span, required super.child});

  final WidgetSpan span;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as TextParentData;
    if (!identical(parentData.span, span)) {
      parentData.span = span;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _SpikeParagraphWidget;
}

class _SpikeInlineScale extends SingleChildRenderObjectWidget {
  const _SpikeInlineScale({
    required this.runFontSize,
    required this.counters,
    required super.child,
  });

  final double runFontSize;
  final SpikeCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SpikeRenderInlineScale(runFontSize, counters);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _SpikeRenderInlineScale renderObject,
  ) {
    renderObject
      ..runFontSize = runFontSize
      ..counters = counters;
  }
}

class _SpikeRenderInlineScale extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _SpikeRenderInlineScale(this._runFontSize, this.counters);

  double _runFontSize;
  double get runFontSize => _runFontSize;
  set runFontSize(double value) {
    if (_runFontSize == value) {
      return;
    }
    _runFontSize = value;
    markNeedsLayout();
  }

  SpikeCounters counters;
  double _scale = 1;

  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) {
      return;
    }
    _scale = value;
    markNeedsLayout();
  }

  double scaleFor(TextScaler scaler) {
    if (spikeMutant == 'zero_division') {
      return scaler.scale(runFontSize) / runFontSize;
    }
    return runFontSize == 0 ? 0 : scaler.scale(runFontSize) / runFontSize;
  }

  BoxConstraints _unscaledConstraints(
    BoxConstraints constraints,
    double factor,
  ) {
    if (factor == 0) {
      return const BoxConstraints();
    }
    return BoxConstraints(maxWidth: constraints.maxWidth / factor);
  }

  Size drySizeFor(double maxWidth, TextScaler scaler) {
    counters.childDryQueries += 1;
    final factor = scaleFor(scaler);
    final childSize =
        child?.getDryLayout(
          _unscaledConstraints(BoxConstraints(maxWidth: maxWidth), factor),
        ) ??
        Size.zero;
    return factor == 0 ? Size.zero : childSize * factor;
  }

  double? dryBaselineFor(
    double maxWidth,
    TextScaler scaler,
    TextBaseline baseline,
  ) {
    final factor = scaleFor(scaler);
    if (spikeMutant == 'zero_baseline_shortcut' && factor == 0) {
      return 0;
    }
    final value = child?.getDryBaseline(
      _unscaledConstraints(BoxConstraints(maxWidth: maxWidth), factor),
      baseline,
    );
    return value == null ? null : value * factor;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(
      drySizeFor(constraints.maxWidth, TextScaler.linear(scale)),
    );
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return dryBaselineFor(
      constraints.maxWidth,
      TextScaler.linear(scale),
      baseline,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final childBaseline = child?.getDistanceToActualBaseline(baseline);
    return childBaseline == null ? null : childBaseline * scale;
  }

  @override
  void performLayout() {
    counters.childWetLayouts += 1;
    final renderChild = child;
    if (renderChild == null) {
      size = constraints.smallest;
      return;
    }
    renderChild.layout(
      _unscaledConstraints(constraints, scale),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      scale == 0 ? Size.zero : renderChild.size * scale,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (spikeMutant == 'no_inline_transform') {
      return;
    }
    transform.scaleByDouble(scale, scale, scale, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final renderChild = child;
    if (renderChild == null || scale == 0) {
      return;
    }
    if (scale == 1) {
      context.paintChild(renderChild, offset);
      return;
    }
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(scale, scale, 1),
      (context, transformedOffset) =>
          context.paintChild(renderChild, transformedOffset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final renderChild = child;
    if (renderChild == null || scale == 0) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(scale, scale, 1),
      position: position,
      hitTest: (result, transformed) =>
          renderChild.hitTest(result, position: transformed),
    );
  }

  @override
  void dispose() {
    if (spikeMutant != 'no_wrapper_dispose') {
      counters.inlineWrapperDisposals += 1;
    }
    super.dispose();
  }
}

class _SpikeRenderParagraph extends RenderParagraph {
  _SpikeRenderParagraph(
    super.text, {
    required super.textDirection,
    required super.maxLines,
    required super.softWrap,
    required super.overflow,
    required super.registrar,
    required super.selectionColor,
    required this.counters,
  });

  SpikeCounters counters;
  double? configuredCandidate;

  Iterable<_SpikeInlineEntry> get _inlineChildren sync* {
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      yield _SpikeInlineEntry(child, _findInlineScale(child));
    }
  }

  _SpikeRenderInlineScale _findInlineScale(RenderBox root) {
    RenderBox current = root;
    while (current is! _SpikeRenderInlineScale) {
      if (current case final RenderProxyBox proxy when proxy.child != null) {
        current = proxy.child!;
      } else {
        throw StateError('Missing spike inline scale wrapper.');
      }
    }
    return current;
  }

  void configureCandidate(TextScaler scaler, double candidate) {
    textScaler = scaler;
    for (final entry in _inlineChildren) {
      entry.scale.scale = entry.scale.scaleFor(scaler);
    }
    configuredCandidate = candidate;
  }

  List<PlaceholderDimensions> dryDimensions(
    double maxWidth,
    TextScaler scaler,
    _SpikeDimensionMode mode,
  ) {
    return <PlaceholderDimensions>[
      for (final entry in _inlineChildren)
        _dryDimension(entry, maxWidth, scaler, mode),
    ];
  }

  PlaceholderDimensions _dryDimension(
    _SpikeInlineEntry entry,
    double maxWidth,
    TextScaler scaler,
    _SpikeDimensionMode mode,
  ) {
    final parentData = entry.host.parentData! as TextParentData;
    final span = parentData.span!;
    final factor = entry.scale.scaleFor(scaler);
    final effectiveMode = spikeMutant == 'intrinsic_uses_dry'
        ? _SpikeDimensionMode.dry
        : mode;
    final size = switch (effectiveMode) {
      _SpikeDimensionMode.dry => entry.scale.drySizeFor(maxWidth, scaler),
      _SpikeDimensionMode.minIntrinsic => Size(
        (entry.scale.child?.getMinIntrinsicWidth(double.infinity) ?? 0) *
            factor,
        0,
      ),
      _SpikeDimensionMode.maxIntrinsic => Size(
        (entry.scale.child?.getMaxIntrinsicWidth(double.infinity) ?? 0) *
            factor,
        0,
      ),
    };
    return PlaceholderDimensions(
      size: size,
      alignment: span.alignment,
      baseline: span.baseline,
      baselineOffset: span.alignment == ui.PlaceholderAlignment.baseline
          ? entry.scale.dryBaselineFor(maxWidth, scaler, span.baseline!)
          : null,
    );
  }

  List<double> get debugInlineScales => <double>[
    for (final entry in _inlineChildren) entry.scale.scale,
  ];

  @override
  void dispose() {
    counters.paragraphDisposals += 1;
    super.dispose();
  }
}

enum _SpikeDimensionMode { dry, minIntrinsic, maxIntrinsic }

final class _SpikeInlineEntry {
  const _SpikeInlineEntry(this.host, this.scale);

  final RenderBox host;
  final _SpikeRenderInlineScale scale;
}

final class _SpikeMeasurement {
  const _SpikeMeasurement({
    required this.candidate,
    required this.fits,
    required this.textSize,
    required this.renderSize,
    required this.baseline,
    required this.minIntrinsicWidth,
    required this.maxIntrinsicWidth,
  });

  final double candidate;
  final bool fits;
  final Size textSize;
  final Size renderSize;
  final double baseline;
  final double minIntrinsicWidth;
  final double maxIntrinsicWidth;
}

final class _SpikeSelection {
  const _SpikeSelection({
    required this.localCandidate,
    required this.renderCandidate,
    required this.localFits,
    required this.measurement,
  });

  final double localCandidate;
  final double renderCandidate;
  final bool localFits;
  final _SpikeMeasurement measurement;
}

class _SpikeRenderFitter extends RenderProxyBox {
  _SpikeRenderFitter({
    required SpikeCandidateDomain domain,
    required double referenceFontSize,
    required TextScaler userScaler,
    required double groupLimit,
    required SpikeCounters counters,
    required ValueChanged<double>? onPublish,
  }) : _domain = domain,
       _referenceFontSize = referenceFontSize,
       _userScaler = userScaler,
       _groupLimit = groupLimit,
       _counters = counters,
       _onPublish = onPublish;

  SpikeCandidateDomain _domain;
  set domain(SpikeCandidateDomain value) {
    if (_domain == value) return;
    _domain = value;
    markNeedsLayout();
  }

  double _referenceFontSize;
  set referenceFontSize(double value) {
    if (_referenceFontSize == value) return;
    _referenceFontSize = value;
    markNeedsLayout();
  }

  TextScaler _userScaler;
  set userScaler(TextScaler value) {
    if (_userScaler == value) return;
    _userScaler = value;
    markNeedsLayout();
  }

  double _groupLimit;
  set groupLimit(double value) {
    if (_groupLimit == value) return;
    _groupLimit = value;
    markNeedsLayout();
  }

  SpikeCounters _counters;
  set counters(SpikeCounters value) {
    _counters = value;
  }

  ValueChanged<double>? _onPublish;
  set onPublish(ValueChanged<double>? value) {
    _onPublish = value;
  }

  _SpikeRenderParagraph get _paragraph => child! as _SpikeRenderParagraph;
  double? debugWetCandidate;
  bool? debugWetFits;
  double? debugWetBaseline;

  TextScaler _scalerFor(double candidate) {
    return SpikeCandidateScaler(
      source: _userScaler,
      candidate: candidate,
      reference: _referenceFontSize,
    );
  }

  bool _fits(Size textSize, Size renderSize, bool didExceedMaxLines) {
    return !didExceedMaxLines &&
        renderSize.width >= textSize.width &&
        renderSize.height >= textSize.height;
  }

  double _project(double localCandidate) {
    return _domain.findLargestThatFits((candidate) {
      return candidate <= localCandidate &&
          _userScaler.scale(candidate) <= _groupLimit;
    }).candidate;
  }

  _SpikeMeasurement _layoutWetCandidate(double candidate) {
    _counters.candidateEvaluations += 1;
    final paragraph = _paragraph;
    final scaler = _scalerFor(candidate);
    if (spikeMutant == 'wet_uses_dry') {
      return _measureDryCandidate(
        candidate,
        constraints,
        _SpikeDimensionMode.dry,
      );
    }
    invokeLayoutCallback<BoxConstraints>((_) {
      paragraph.configureCandidate(scaler, candidate);
    });
    paragraph.layout(constraints, parentUsesSize: true);
    _counters.paragraphWetLayouts += 1;
    final textSize = paragraph.textSize;
    final renderSize = constraints.constrain(textSize);
    return _SpikeMeasurement(
      candidate: candidate,
      fits: _fits(textSize, renderSize, paragraph.didExceedMaxLines),
      textSize: textSize,
      renderSize: renderSize,
      baseline: paragraph.getDistanceToBaseline(TextBaseline.alphabetic) ?? 0,
      minIntrinsicWidth: 0,
      maxIntrinsicWidth: 0,
    );
  }

  _SpikeSelection _selectWet() {
    final measured = <double, _SpikeMeasurement>{};
    final local = _domain.findLargestThatFits((candidate) {
      final measurement = _layoutWetCandidate(candidate);
      measured[candidate] = measurement;
      return measurement.fits;
    });
    final renderCandidate = _project(local.candidate);
    var finalMeasurement = measured[renderCandidate];
    if (finalMeasurement == null ||
        _paragraph.configuredCandidate != renderCandidate) {
      if (spikeMutant == 'skip_final_layout') {
        finalMeasurement = measured.values.last;
      } else {
        _counters.finalRelayouts += 1;
        finalMeasurement = _layoutWetCandidate(renderCandidate);
      }
    }
    return _SpikeSelection(
      localCandidate: local.candidate,
      renderCandidate: renderCandidate,
      localFits: local.fits,
      measurement: finalMeasurement,
    );
  }

  _SpikeMeasurement _measureDryCandidate(
    double candidate,
    BoxConstraints constraints,
    _SpikeDimensionMode dimensionMode,
  ) {
    final paragraph = _paragraph;
    final scaler = _scalerFor(candidate);
    final dimensions = paragraph.dryDimensions(
      constraints.maxWidth,
      scaler,
      dimensionMode,
    );
    final painter = TextPainter(
      text: paragraph.text,
      textAlign: paragraph.textAlign,
      textDirection: paragraph.textDirection,
      textScaler: scaler,
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      textHeightBehavior: paragraph.textHeightBehavior,
    );
    _counters.temporaryPaintersCreated += 1;
    try {
      painter
        ..setPlaceholderDimensions(dimensions)
        ..layout(
          minWidth: constraints.minWidth,
          maxWidth:
              paragraph.softWrap || paragraph.overflow == TextOverflow.ellipsis
              ? constraints.maxWidth
              : double.infinity,
        );
      final textSize = painter.size;
      final renderSize = constraints.constrain(textSize);
      return _SpikeMeasurement(
        candidate: candidate,
        fits: _fits(textSize, renderSize, painter.didExceedMaxLines),
        textSize: textSize,
        renderSize: renderSize,
        baseline: painter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        ),
        minIntrinsicWidth: painter.minIntrinsicWidth,
        maxIntrinsicWidth: painter.maxIntrinsicWidth,
      );
    } finally {
      if (spikeMutant != 'no_dispose') {
        painter.dispose();
        _counters.temporaryPaintersDisposed += 1;
      }
    }
  }

  _SpikeSelection _selectDry(
    BoxConstraints constraints, {
    _SpikeDimensionMode dimensionMode = _SpikeDimensionMode.dry,
  }) {
    _counters.drySelections += 1;
    final measurements = <double, _SpikeMeasurement>{};
    final local = _domain.findLargestThatFits((candidate) {
      final measurement = _measureDryCandidate(
        candidate,
        constraints,
        dimensionMode,
      );
      measurements[candidate] = measurement;
      return measurement.fits;
    });
    final renderCandidate = _project(local.candidate);
    final measurement =
        measurements[renderCandidate] ??
        _measureDryCandidate(renderCandidate, constraints, dimensionMode);
    if (spikeMutant == 'dry_publish') {
      _publish(local.candidate);
    }
    return _SpikeSelection(
      localCandidate: local.candidate,
      renderCandidate: renderCandidate,
      localFits: local.fits,
      measurement: measurement,
    );
  }

  void _publish(double candidate) {
    _counters.publications += 1;
    _onPublish?.call(_userScaler.scale(candidate));
  }

  double debugSelectDryCandidate(BoxConstraints constraints) {
    return _selectDry(constraints).renderCandidate;
  }

  List<double> get debugInlineScales => _paragraph.debugInlineScales;

  @override
  void performLayout() {
    _counters.outerPerformLayouts += 1;
    final selection = _selectWet();
    size = selection.measurement.renderSize;
    debugWetCandidate = selection.renderCandidate;
    debugWetFits = selection.localFits;
    debugWetBaseline = selection.measurement.baseline;
    _publish(selection.localCandidate);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _selectDry(constraints).measurement.renderSize;
  }

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    return _selectDry(constraints).measurement.baseline;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return debugWetBaseline;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final constraints = BoxConstraints(
      maxHeight: height.isFinite ? height : double.infinity,
    );
    return _selectDry(
      constraints,
      dimensionMode: _SpikeDimensionMode.minIntrinsic,
    ).measurement.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final constraints = BoxConstraints(
      maxHeight: height.isFinite ? height : double.infinity,
    );
    return _selectDry(
      constraints,
      dimensionMode: _SpikeDimensionMode.maxIntrinsic,
    ).measurement.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _selectDry(
      BoxConstraints(maxWidth: width),
    ).measurement.textSize.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return computeMinIntrinsicHeight(width);
  }
}

/// A child that deliberately supports wet layout but rejects dry layout.
class SpikeWetOnlyBox extends SingleChildRenderObjectWidget {
  const SpikeWetOnlyBox({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SpikeWetOnlyRenderBox();
  }
}

class _SpikeWetOnlyRenderBox extends RenderProxyBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    throw FlutterError('SpikeWetOnlyBox intentionally has no dry layout.');
  }
}

/// A deterministic child whose height is non-monotone in inverse width.
class SpikeNonMonotoneBox extends LeafRenderObjectWidget {
  const SpikeNonMonotoneBox({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SpikeNonMonotoneRenderBox();
}

class _SpikeNonMonotoneRenderBox extends RenderBox {
  Size _sizeFor(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final height = maxWidth > 75
        ? 10.0
        : maxWidth > 40
        ? 20.0
        : maxWidth > 28
        ? 5.0
        : 10.0;
    return constraints.constrain(Size(1, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() {
    size = _sizeFor(constraints);
  }
}

/// Returns the temporary fitter render object for black-box tests.
RenderBox spikeRenderBox(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is _SpikeRenderFitter) {
    return renderObject;
  }
  throw StateError('Expected the spike fitter render object.');
}

/// Test-only observations without exporting a production-facing API.
extension SpikeRenderObservations on RenderBox {
  _SpikeRenderFitter get _spike => this as _SpikeRenderFitter;

  double? get spikeWetCandidate => _spike.debugWetCandidate;
  bool? get spikeWetFits => _spike.debugWetFits;
  double? get spikeWetBaseline => _spike.debugWetBaseline;
  double? get spikeConfiguredCandidate => _spike._paragraph.configuredCandidate;
  List<double> get spikeInlineScales => _spike.debugInlineScales;
  RenderParagraph get spikeParagraph => _spike._paragraph;
  double spikeDryCandidate(BoxConstraints constraints) =>
      _spike.debugSelectDryCandidate(constraints);
}

/// A test-only entry point for exercising the inline scale wrapper directly.
class SpikeInlineScaleProbe extends SingleChildRenderObjectWidget {
  const SpikeInlineScaleProbe({
    super.key,
    required this.runFontSize,
    required this.scaler,
    required this.counters,
    required super.child,
  });

  final double runFontSize;
  final TextScaler scaler;
  final SpikeCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _SpikeRenderInlineScale(runFontSize, counters);
    renderObject.scale = renderObject.scaleFor(scaler);
    return renderObject;
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final scale = renderObject as _SpikeRenderInlineScale;
    scale
      ..runFontSize = runFontSize
      ..counters = counters
      ..scale = scale.scaleFor(scaler);
  }
}

/// Mutates a probe factor without invalidating Flutter's dry-layout cache.
void spikeSetScaleWithoutInvalidation(RenderBox box, double scale) {
  final renderObject = box as _SpikeRenderInlineScale;
  renderObject._scale = scale;
}

/// Computes a probe size with an explicit factor, bypassing render caching.
Size spikePureDrySizeAtScale(
  RenderBox box,
  BoxConstraints constraints,
  double scale,
) {
  if (spikeMutant == 'explicit_dry_uses_cache') {
    return box.getDryLayout(constraints);
  }
  final renderObject = box as _SpikeRenderInlineScale;
  final childSize =
      renderObject.child?.getDryLayout(
        scale == 0
            ? const BoxConstraints()
            : BoxConstraints(maxWidth: constraints.maxWidth / scale),
      ) ??
      Size.zero;
  return constraints.constrain(scale == 0 ? Size.zero : childSize * scale);
}

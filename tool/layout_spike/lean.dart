import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'spike.dart';

/// Counters for the temporary lean layout contract.
final class SpikeLeanCounters {
  int candidateMeasurements = 0;
  int temporaryPaintersCreated = 0;
  int temporaryPaintersDisposed = 0;
  int dryLayouts = 0;
  int dryBaselines = 0;
  int intrinsicQueries = 0;
  int wetLayouts = 0;
  int publications = 0;
  int placeholderDryLayouts = 0;
  int placeholderDryBaselines = 0;
  int placeholderMinIntrinsicWidths = 0;
  int placeholderMaxIntrinsicWidths = 0;
  int placeholderMinIntrinsicHeights = 0;
  int placeholderMaxIntrinsicHeights = 0;
  int placeholderWetLayouts = 0;
}

/// A strictly-lazy replacement prototype with a deterministic text fallback.
///
/// Dry and intrinsic queries never build or inspect [overflowReplacement]. If
/// the local text does not fit even at the smallest candidate, those queries
/// return the constrained paragraph metrics at that smallest candidate. Wet
/// layout still builds and lays out [overflowReplacement] normally.
class SpikeLeanOverflowParagraph
    extends ConstrainedLayoutBuilder<BoxConstraints> {
  SpikeLeanOverflowParagraph({
    super.key,
    required InlineSpan text,
    required SpikeCandidateDomain domain,
    required double referenceFontSize,
    required SpikeCounters textCounters,
    required SpikeLeanCounters leanCounters,
    required Widget overflowReplacement,
    TextScaler userScaler = TextScaler.noScaling,
    double groupLimit = double.infinity,
    ValueChanged<double>? onPublish,
    TextDirection textDirection = TextDirection.ltr,
    int? maxLines,
    bool softWrap = true,
    TextOverflow overflow = TextOverflow.clip,
  }) : _text = text,
       _domain = domain,
       _referenceFontSize = referenceFontSize,
       _userScaler = userScaler,
       _groupLimit = groupLimit,
       _onPublish = onPublish,
       _textDirection = textDirection,
       _maxLines = maxLines,
       _softWrap = softWrap,
       _overflow = overflow,
       _leanCounters = leanCounters,
       super(
         builder: (context, constraints) {
           final selection = _selectLeanText(
             text: text,
             domain: domain,
             referenceFontSize: referenceFontSize,
             userScaler: userScaler,
             groupLimit: groupLimit,
             textDirection: textDirection,
             maxLines: maxLines,
             softWrap: softWrap,
             overflow: overflow,
             constraints: constraints,
             counters: leanCounters,
           );
           if (!selection.localFits) {
             return overflowReplacement;
           }
           return SpikeAutoParagraph(
             text: text,
             domain: domain,
             referenceFontSize: referenceFontSize,
             counters: textCounters,
             userScaler: userScaler,
             groupLimit: groupLimit,
             textDirection: textDirection,
             maxLines: maxLines,
             softWrap: softWrap,
             overflow: overflow,
           );
         },
       );

  final InlineSpan _text;
  final SpikeCandidateDomain _domain;
  final double _referenceFontSize;
  final TextScaler _userScaler;
  final double _groupLimit;
  final ValueChanged<double>? _onPublish;
  final TextDirection _textDirection;
  final int? _maxLines;
  final bool _softWrap;
  final TextOverflow _overflow;
  final SpikeLeanCounters _leanCounters;

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox>
  createRenderObject(BuildContext context) {
    return _SpikeRenderLeanOverflow(
      text: _text,
      domain: _domain,
      referenceFontSize: _referenceFontSize,
      userScaler: _userScaler,
      groupLimit: _groupLimit,
      onPublish: _onPublish,
      textDirection: _textDirection,
      maxLines: _maxLines,
      softWrap: _softWrap,
      overflow: _overflow,
      counters: _leanCounters,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final leanRenderObject = renderObject as _SpikeRenderLeanOverflow;
    leanRenderObject
      ..text = _text
      ..domain = _domain
      ..referenceFontSize = _referenceFontSize
      ..userScaler = _userScaler
      ..groupLimit = _groupLimit
      ..onPublish = _onPublish
      ..textDirection = _textDirection
      ..maxLines = _maxLines
      ..softWrap = _softWrap
      ..overflow = _overflow
      ..counters = _leanCounters;
  }
}

class _SpikeRenderLeanOverflow extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  _SpikeRenderLeanOverflow({
    required InlineSpan text,
    required SpikeCandidateDomain domain,
    required double referenceFontSize,
    required TextScaler userScaler,
    required double groupLimit,
    required ValueChanged<double>? onPublish,
    required TextDirection textDirection,
    required int? maxLines,
    required bool softWrap,
    required TextOverflow overflow,
    required SpikeLeanCounters counters,
  }) : _text = text,
       _domain = domain,
       _referenceFontSize = referenceFontSize,
       _userScaler = userScaler,
       _groupLimit = groupLimit,
       _onPublish = onPublish,
       _textDirection = textDirection,
       _maxLines = maxLines,
       _softWrap = softWrap,
       _overflow = overflow,
       _counters = counters;

  InlineSpan _text;
  set text(InlineSpan value) {
    if (_text == value) {
      return;
    }
    _text = value;
    markNeedsLayout();
  }

  SpikeCandidateDomain _domain;
  set domain(SpikeCandidateDomain value) {
    if (_domain == value) {
      return;
    }
    _domain = value;
    markNeedsLayout();
  }

  double _referenceFontSize;
  set referenceFontSize(double value) {
    if (_referenceFontSize == value) {
      return;
    }
    _referenceFontSize = value;
    markNeedsLayout();
  }

  TextScaler _userScaler;
  set userScaler(TextScaler value) {
    if (_userScaler == value) {
      return;
    }
    _userScaler = value;
    markNeedsLayout();
  }

  double _groupLimit;
  set groupLimit(double value) {
    if (_groupLimit == value) {
      return;
    }
    _groupLimit = value;
    markNeedsLayout();
  }

  ValueChanged<double>? _onPublish;
  set onPublish(ValueChanged<double>? value) {
    _onPublish = value;
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsLayout();
  }

  int? _maxLines;
  set maxLines(int? value) {
    if (_maxLines == value) {
      return;
    }
    _maxLines = value;
    markNeedsLayout();
  }

  bool _softWrap;
  set softWrap(bool value) {
    if (_softWrap == value) {
      return;
    }
    _softWrap = value;
    markNeedsLayout();
  }

  TextOverflow _overflow;
  set overflow(TextOverflow value) {
    if (_overflow == value) {
      return;
    }
    _overflow = value;
    markNeedsLayout();
  }

  SpikeLeanCounters _counters;
  set counters(SpikeLeanCounters value) {
    _counters = value;
  }

  _SpikeLeanSelection _select(
    BoxConstraints constraints, {
    _SpikeLeanDimensionMode mode = _SpikeLeanDimensionMode.dry,
  }) {
    return _selectLeanText(
      text: _text,
      domain: _domain,
      referenceFontSize: _referenceFontSize,
      userScaler: _userScaler,
      groupLimit: _groupLimit,
      textDirection: _textDirection,
      maxLines: _maxLines,
      softWrap: _softWrap,
      overflow: _overflow,
      constraints: constraints,
      counters: _counters,
      mode: mode,
    );
  }

  @override
  void performLayout() {
    _counters.wetLayouts += 1;
    final selection = _select(constraints);
    runLayoutCallback();
    final renderChild = child;
    if (renderChild == null) {
      size = constraints.smallest;
    } else {
      renderChild.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(renderChild.size);
    }
    _counters.publications += 1;
    _onPublish?.call(_userScaler.scale(selection.localCandidate));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _counters.dryLayouts += 1;
    if (spikeMutant == 'lean_reads_active_child') {
      return constraints.constrain(
        child?.getDryLayout(constraints) ?? Size.zero,
      );
    }
    return _select(constraints).measurement.renderSize;
  }

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    _counters.dryBaselines += 1;
    return _select(constraints).measurement.baseline;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return child?.getDistanceToActualBaseline(baseline);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _counters.intrinsicQueries += 1;
    return _select(
      BoxConstraints(maxHeight: height.isFinite ? height : double.infinity),
      mode: _SpikeLeanDimensionMode.minIntrinsic,
    ).measurement.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _counters.intrinsicQueries += 1;
    return _select(
      BoxConstraints(maxHeight: height.isFinite ? height : double.infinity),
      mode: _SpikeLeanDimensionMode.maxIntrinsic,
    ).measurement.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _counters.intrinsicQueries += 1;
    return _select(BoxConstraints(maxWidth: width)).measurement.textSize.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    _counters.intrinsicQueries += 1;
    return _select(BoxConstraints(maxWidth: width)).measurement.textSize.height;
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

enum _SpikeLeanDimensionMode { dry, minIntrinsic, maxIntrinsic }

final class _SpikeLeanMeasurement {
  const _SpikeLeanMeasurement({
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

final class _SpikeLeanSelection {
  const _SpikeLeanSelection({
    required this.localCandidate,
    required this.localFits,
    required this.measurement,
  });

  final double localCandidate;
  final bool localFits;
  final _SpikeLeanMeasurement measurement;
}

_SpikeLeanSelection _selectLeanText({
  required InlineSpan text,
  required SpikeCandidateDomain domain,
  required double referenceFontSize,
  required TextScaler userScaler,
  required double groupLimit,
  required TextDirection textDirection,
  required int? maxLines,
  required bool softWrap,
  required TextOverflow overflow,
  required BoxConstraints constraints,
  required SpikeLeanCounters counters,
  _SpikeLeanDimensionMode mode = _SpikeLeanDimensionMode.dry,
}) {
  final measurements = <double, _SpikeLeanMeasurement>{};
  final local = domain.findLargestThatFits((candidate) {
    final measurement = _measureLeanText(
      text: text,
      candidate: candidate,
      referenceFontSize: referenceFontSize,
      userScaler: userScaler,
      textDirection: textDirection,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      constraints: constraints,
      counters: counters,
    );
    measurements[candidate] = measurement;
    return measurement.fits;
  });
  final projected = domain.findLargestThatFits((candidate) {
    return candidate <= local.candidate &&
        userScaler.scale(candidate) <= groupLimit;
  }).candidate;
  final fallbackCandidate = local.fits ? projected : domain.minimum;
  final effectiveCandidate =
      spikeMutant == 'lean_fallback_max_candidate' && !local.fits
      ? domain.maximum
      : fallbackCandidate;
  final measurement =
      measurements[effectiveCandidate] ??
      _measureLeanText(
        text: text,
        candidate: effectiveCandidate,
        referenceFontSize: referenceFontSize,
        userScaler: userScaler,
        textDirection: textDirection,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
        constraints: constraints,
        counters: counters,
      );
  return _SpikeLeanSelection(
    localCandidate: local.candidate,
    localFits: local.fits,
    measurement: switch (mode) {
      _SpikeLeanDimensionMode.dry => measurement,
      _SpikeLeanDimensionMode.minIntrinsic => measurement,
      _SpikeLeanDimensionMode.maxIntrinsic => measurement,
    },
  );
}

_SpikeLeanMeasurement _measureLeanText({
  required InlineSpan text,
  required double candidate,
  required double referenceFontSize,
  required TextScaler userScaler,
  required TextDirection textDirection,
  required int? maxLines,
  required bool softWrap,
  required TextOverflow overflow,
  required BoxConstraints constraints,
  required SpikeLeanCounters counters,
}) {
  counters.candidateMeasurements += 1;
  final painter = TextPainter(
    text: text,
    textDirection: textDirection,
    textScaler: SpikeCandidateScaler(
      source: userScaler,
      candidate: candidate,
      reference: referenceFontSize,
    ),
    maxLines: maxLines,
    ellipsis: overflow == TextOverflow.ellipsis ? '\u2026' : null,
  );
  counters.temporaryPaintersCreated += 1;
  try {
    painter
      ..setPlaceholderDimensions(_zeroPlaceholderDimensions(text))
      ..layout(
        minWidth: constraints.minWidth,
        maxWidth: softWrap || overflow == TextOverflow.ellipsis
            ? constraints.maxWidth
            : double.infinity,
      );
    final textSize = painter.size;
    final renderSize = constraints.constrain(textSize);
    return _SpikeLeanMeasurement(
      candidate: candidate,
      fits:
          !painter.didExceedMaxLines &&
          renderSize.width >= textSize.width &&
          renderSize.height >= textSize.height,
      textSize: textSize,
      renderSize: renderSize,
      baseline: painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      ),
      minIntrinsicWidth: painter.minIntrinsicWidth,
      maxIntrinsicWidth: painter.maxIntrinsicWidth,
    );
  } finally {
    painter.dispose();
    counters.temporaryPaintersDisposed += 1;
  }
}

List<PlaceholderDimensions> _zeroPlaceholderDimensions(InlineSpan root) {
  final dimensions = <PlaceholderDimensions>[];

  void visit(InlineSpan span) {
    if (span case final WidgetSpan widgetSpan) {
      dimensions.add(
        PlaceholderDimensions(
          size: Size.zero,
          alignment: widgetSpan.alignment,
          baseline: widgetSpan.baseline,
          baselineOffset:
              widgetSpan.alignment == ui.PlaceholderAlignment.baseline
              ? 0
              : null,
        ),
      );
    }
    span.visitDirectChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return dimensions;
}

/// Internal public witness for a future zero-placeholder dry fallback.
///
/// Wet layout delegates to the arbitrary child. Dry size and baseline are
/// deliberately zero and do not query that child, so dry-only ancestors do not
/// crash when the child only supports wet layout.
class SpikeLeanDryPlaceholder extends SingleChildRenderObjectWidget {
  const SpikeLeanDryPlaceholder({
    super.key,
    required this.counters,
    required super.child,
  });

  final SpikeLeanCounters counters;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SpikeRenderLeanDryPlaceholder(counters);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _SpikeRenderLeanDryPlaceholder).counters = counters;
  }
}

class _SpikeRenderLeanDryPlaceholder extends RenderProxyBox {
  _SpikeRenderLeanDryPlaceholder(this.counters);

  SpikeLeanCounters counters;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    counters.placeholderDryLayouts += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_dry') {
      return super.computeDryLayout(constraints);
    }
    return constraints.constrain(Size.zero);
  }

  @override
  double computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    counters.placeholderDryBaselines += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_dry') {
      return super.computeDryBaseline(constraints, baseline) ?? 0;
    }
    return 0;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    counters.placeholderMinIntrinsicWidths += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_intrinsic') {
      return super.computeMinIntrinsicWidth(height);
    }
    return 0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    counters.placeholderMaxIntrinsicWidths += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_intrinsic') {
      return super.computeMaxIntrinsicWidth(height);
    }
    return 0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    counters.placeholderMinIntrinsicHeights += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_intrinsic') {
      return super.computeMinIntrinsicHeight(width);
    }
    return 0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    counters.placeholderMaxIntrinsicHeights += 1;
    if (spikeMutant == 'lean_placeholder_calls_child_intrinsic') {
      return super.computeMaxIntrinsicHeight(width);
    }
    return 0;
  }

  @override
  void performLayout() {
    counters.placeholderWetLayouts += 1;
    super.performLayout();
  }
}

/// An arbitrary child that supports wet layout and rejects every dry metric.
class SpikeLeanWetOnlyTrap extends SingleChildRenderObjectWidget {
  const SpikeLeanWetOnlyTrap({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _SpikeRenderLeanWetOnlyTrap();
  }
}

class _SpikeRenderLeanWetOnlyTrap extends RenderProxyBox {
  Never _reject(String metric) {
    throw FlutterError('SpikeLeanWetOnlyTrap rejects $metric.');
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

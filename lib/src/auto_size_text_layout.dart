part of '../auto_size_text.dart';

const double _doubleEpsilon = 2.220446049250313e-16;
const double _candidateToleranceFactor = 8 * _doubleEpsilon;
const int _maximumExactCandidateIndex = 0x1fffffffffffff;

double _canonicalCandidateZero(double value) => value == 0 ? 0 : value;

bool _candidatesAreNearlyEqual(double first, double second) {
  final firstMagnitude = first.abs();
  final secondMagnitude = second.abs();
  final largerMagnitude = firstMagnitude > secondMagnitude
      ? firstMagnitude
      : secondMagnitude;
  final scale = largerMagnitude > 1 ? largerMagnitude : 1;
  return (first - second).abs() <= _candidateToleranceFactor * scale;
}

void _validateCandidateInputs({
  required double referenceFontSize,
  required double? textScaleFactor,
}) {
  _requireFiniteNonNegative(referenceFontSize, 'style.fontSize');

  if (textScaleFactor != null) {
    _requireFiniteNonNegative(textScaleFactor, 'textScaleFactor');
  }
}

void _validateRegularCandidateInputs({
  required double minFontSize,
  required double maxFontSize,
  required double stepGranularity,
}) {
  _requireFiniteNonNegative(minFontSize, 'minFontSize');
  _requireFiniteNonNegative(stepGranularity, 'stepGranularity');
  if (stepGranularity < 0.1) {
    throw ArgumentError.value(
      stepGranularity,
      'stepGranularity',
      'must be greater than or equal to 0.1',
    );
  }

  if ((!maxFontSize.isFinite && maxFontSize != double.infinity) ||
      maxFontSize <= 0) {
    throw ArgumentError.value(
      maxFontSize,
      'maxFontSize',
      'must be finite and positive, or positive infinity',
    );
  }
  if (maxFontSize < minFontSize) {
    throw ArgumentError.value(
      maxFontSize,
      'maxFontSize',
      'must be greater than or equal to minFontSize',
    );
  }
}

void _requireFiniteNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be finite and non-negative');
  }
}

final RegExp _historicalWhitespace = RegExp(r'\s');

Iterable<TextRange> _unbreakableTextRanges(String text) sync* {
  var rangeStart = 0;
  for (final match in _historicalWhitespace.allMatches(text)) {
    final separator = match.group(0)!;
    if (separator == '\u00A0' || separator == '\u202F') {
      continue;
    }
    if (rangeStart < match.start) {
      yield TextRange(start: rangeStart, end: match.start);
    }
    rangeStart = match.end;
  }
  if (rangeStart < text.length) {
    yield TextRange(start: rangeStart, end: text.length);
  }
}

final class _UnbreakableTextSnapshot {
  factory _UnbreakableTextSnapshot.from(InlineSpan text) {
    final plainText = text.toPlainText(includeSemanticsLabels: false);
    return _UnbreakableTextSnapshot._(
      List<TextRange>.unmodifiable(_unbreakableTextRanges(plainText)),
    );
  }

  const _UnbreakableTextSnapshot._(this.ranges);

  final List<TextRange> ranges;
}

bool _containsWidgetSpan(InlineSpan text) {
  var containsWidgetSpan = false;
  text.visitChildren((span) {
    if (span is WidgetSpan) {
      containsWidgetSpan = true;
      return false;
    }
    return true;
  });
  return containsWidgetSpan;
}

TextSpan _applyTextStyleOverride(TextSpan text, TextStyle? override) {
  if (override == null || text.runtimeType != TextSpan) {
    return text;
  }
  return TextSpan(
    text: text.text,
    children: text.children?.map((child) {
      if (child is TextSpan && child.runtimeType == TextSpan) {
        return _applyTextStyleOverride(child, override);
      }
      return child;
    }).toList(),
    style: text.style?.merge(override) ?? override,
    recognizer: text.recognizer,
    mouseCursor: text.mouseCursor,
    onEnter: text.onEnter,
    onExit: text.onExit,
    semanticsLabel: text.semanticsLabel,
    semanticsIdentifier: text.semanticsIdentifier,
    locale: text.locale,
    spellOut: text.spellOut,
  );
}

final class _CandidateTextScaler extends TextScaler {
  _CandidateTextScaler({
    required this.source,
    required double candidate,
    required double reference,
  }) : candidate = _canonicalCandidateZero(candidate),
       reference = _canonicalCandidateZero(reference) {
    _requireFiniteNonNegative(this.candidate, 'candidateFontSize');
    _requireFiniteNonNegative(this.reference, 'referenceFontSize');
    if (this.reference == 0) {
      throw ArgumentError.value(
        this.reference,
        'referenceFontSize',
        'must be positive when composing a TextScaler',
      );
    }
  }

  final TextScaler source;
  final double candidate;
  final double reference;

  @override
  double scale(double fontSize) {
    _requireFiniteNonNegative(fontSize, 'fontSize');
    final adjustedFontSize = fontSize * candidate / reference;
    _requireFiniteNonNegative(adjustedFontSize, 'adjustedFontSize');
    final scaledFontSize = source.scale(adjustedFontSize);
    _requireFiniteNonNegative(scaledFontSize, 'scaledFontSize');
    return _canonicalCandidateZero(scaledFontSize);
  }

  @override
  double get textScaleFactor {
    final estimate = scale(reference) / reference;
    _requireFiniteNonNegative(estimate, 'textScaleFactor');
    return _canonicalCandidateZero(estimate);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _CandidateTextScaler &&
            source == other.source &&
            candidate == other.candidate &&
            reference == other.reference;
  }

  @override
  int get hashCode => Object.hash(source, candidate, reference);
}

final class _EffectiveTextConfiguration {
  const _EffectiveTextConfiguration({
    required this.baseStyle,
    required this.measurementStyle,
    required this.measurementTextStyleOverride,
    required this.renderStyle,
    required this.measurementStrutStyle,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.softWrap,
    required this.overflow,
    required this.maxLines,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.userScaler,
  });

  final TextStyle baseStyle;
  final TextStyle measurementStyle;
  final TextStyle? measurementTextStyleOverride;
  final TextStyle? renderStyle;
  final StrutStyle? measurementStrutStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final TextScaler userScaler;

  double get referenceFontSize => baseStyle.fontSize!;
}

final class _AutoSizeTextMeasurement {
  const _AutoSizeTextMeasurement({
    required this.fits,
    required this.textSize,
    required this.renderSize,
    required this.baseline,
    required this.minIntrinsicWidth,
    required this.maxIntrinsicWidth,
  });

  final bool fits;
  final Size textSize;
  final Size renderSize;
  final double baseline;
  final double minIntrinsicWidth;
  final double maxIntrinsicWidth;
}

final class _AutoSizeTextSelection {
  const _AutoSizeTextSelection({
    required this.localCandidate,
    required this.localEffectiveFontSize,
    required this.localFits,
    required this.renderCandidate,
    required this.measurement,
  });

  final double localCandidate;
  final double localEffectiveFontSize;
  final bool localFits;
  final double renderCandidate;
  final _AutoSizeTextMeasurement measurement;
}

/// Immutable input used by wet, dry and intrinsic paragraph measurement.
final class _AutoSizeTextLayoutSnapshot {
  factory _AutoSizeTextLayoutSnapshot({
    required String? data,
    required TextSpan? textSpan,
    required Key? textKey,
    required TextStyle? renderStyle,
    required StrutStyle? renderStrutStyle,
    required TextAlign? renderTextAlign,
    required TextDirection? renderTextDirection,
    required Locale? renderLocale,
    required bool? renderSoftWrap,
    required TextOverflow? renderOverflow,
    required int? renderMaxLines,
    required String? semanticsLabel,
    required bool wrapWords,
    required _EffectiveTextConfiguration configuration,
    required _CandidateSet candidates,
    required double groupLimit,
  }) {
    final measurementTextSpan = textSpan == null
        ? null
        : _applyTextStyleOverride(
            textSpan,
            configuration.measurementTextStyleOverride,
          );
    return _AutoSizeTextLayoutSnapshot._(
      data: data,
      textSpan: textSpan,
      textKey: textKey,
      renderStyle: renderStyle,
      renderStrutStyle: renderStrutStyle,
      renderTextAlign: renderTextAlign,
      renderTextDirection: renderTextDirection,
      renderLocale: renderLocale,
      renderSoftWrap: renderSoftWrap,
      renderOverflow: renderOverflow,
      renderMaxLines: renderMaxLines,
      semanticsLabel: semanticsLabel,
      configuration: configuration,
      candidates: candidates,
      groupLimit: groupLimit,
      measurementTextSpan: measurementTextSpan,
      unbreakableTextSnapshot: wrapWords
          ? null
          : _UnbreakableTextSnapshot.from(
              measurementTextSpan ?? TextSpan(text: data),
            ),
    );
  }

  const _AutoSizeTextLayoutSnapshot._({
    required this.data,
    required this.textSpan,
    required this.textKey,
    required this.renderStyle,
    required this.renderStrutStyle,
    required this.renderTextAlign,
    required this.renderTextDirection,
    required this.renderLocale,
    required this.renderSoftWrap,
    required this.renderOverflow,
    required this.renderMaxLines,
    required this.semanticsLabel,
    required this.configuration,
    required this.candidates,
    required this.groupLimit,
    required this.measurementTextSpan,
    required this.unbreakableTextSnapshot,
  });

  final String? data;
  final TextSpan? textSpan;
  final Key? textKey;
  final TextStyle? renderStyle;
  final StrutStyle? renderStrutStyle;
  final TextAlign? renderTextAlign;
  final TextDirection? renderTextDirection;
  final Locale? renderLocale;
  final bool? renderSoftWrap;
  final TextOverflow? renderOverflow;
  final int? renderMaxLines;
  final String? semanticsLabel;
  final _EffectiveTextConfiguration configuration;
  final _CandidateSet candidates;
  final double groupLimit;
  final TextSpan? measurementTextSpan;
  final _UnbreakableTextSnapshot? unbreakableTextSnapshot;

  _AutoSizeTextSelection select(BoxConstraints constraints) {
    final measurements = <double, _AutoSizeTextMeasurement>{};
    final local = candidates.findLargestThatFits((candidate) {
      final measurement = _measure(candidate, constraints);
      measurements[candidate] = measurement;
      return measurement.fits;
    });
    final renderCandidate = candidates.findLargestThatFits((candidate) {
      if (candidate > local.value) {
        return false;
      }
      return _checkedEffectiveFontSize(
            configuration.userScaler,
            candidate,
            name: 'projectedFontSize',
          ) <=
          groupLimit;
    }).value;
    final measurement =
        measurements[renderCandidate] ?? _measure(renderCandidate, constraints);
    return _AutoSizeTextSelection(
      localCandidate: local.value,
      localEffectiveFontSize: _checkedEffectiveFontSize(
        configuration.userScaler,
        local.value,
        name: 'calculatedFontSize',
      ),
      localFits: local.fits,
      renderCandidate: renderCandidate,
      measurement: measurement,
    );
  }

  double intrinsicHeight(double candidate, double width) {
    final painter = _createPainter(candidate);
    try {
      painter.layout(
        minWidth: width,
        maxWidth:
            configuration.softWrap ||
                configuration.overflow == TextOverflow.ellipsis
            ? width
            : double.infinity,
      );
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  Widget buildParagraph(double candidate) {
    final referenceFontSize = configuration.referenceFontSize;
    final effectiveRenderStyle = referenceFontSize == 0
        ? (renderStyle ?? const TextStyle()).copyWith(fontSize: candidate)
        : renderStyle;
    final candidateScaler = _candidateScaler(candidate);
    final child = data != null
        ? Text(
            data!,
            style: effectiveRenderStyle,
            strutStyle: renderStrutStyle,
            textAlign: renderTextAlign,
            textDirection: renderTextDirection,
            locale: renderLocale,
            softWrap: renderSoftWrap,
            overflow: renderOverflow,
            textScaler: candidateScaler,
            maxLines: renderMaxLines,
            semanticsLabel: semanticsLabel,
            textWidthBasis: configuration.textWidthBasis,
            textHeightBehavior: configuration.textHeightBehavior,
          )
        : Text.rich(
            textSpan!,
            style: effectiveRenderStyle,
            strutStyle: renderStrutStyle,
            textAlign: renderTextAlign,
            textDirection: renderTextDirection,
            locale: renderLocale,
            softWrap: renderSoftWrap,
            overflow: renderOverflow,
            textScaler: candidateScaler,
            maxLines: renderMaxLines,
            semanticsLabel: semanticsLabel,
            textWidthBasis: configuration.textWidthBasis,
            textHeightBehavior: configuration.textHeightBehavior,
          );
    return _AutoSizeTextParagraph(key: textKey, child: child);
  }

  _AutoSizeTextMeasurement _measure(
    double candidate,
    BoxConstraints constraints,
  ) {
    var unbreakableRangesFit = true;
    final unbreakableSnapshot = unbreakableTextSnapshot;
    if (unbreakableSnapshot != null) {
      final wordPainter = _createPainter(candidate, includeMaxLines: false);
      try {
        wordPainter.layout(maxWidth: double.infinity);
        for (final range in unbreakableSnapshot.ranges) {
          final boxes = wordPainter.getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          );
          final rangeWidth = boxes.fold<double>(
            0,
            (width, box) => width + (box.right - box.left).abs(),
          );
          if (rangeWidth > constraints.maxWidth) {
            unbreakableRangesFit = false;
            break;
          }
        }
      } finally {
        wordPainter.dispose();
      }
    }

    final painter = _createPainter(candidate);
    try {
      painter.layout(
        minWidth: constraints.minWidth,
        maxWidth:
            configuration.softWrap ||
                configuration.overflow == TextOverflow.ellipsis
            ? constraints.maxWidth
            : double.infinity,
      );
      final textSize = painter.size;
      final renderSize = constraints.constrain(textSize);
      return _AutoSizeTextMeasurement(
        fits:
            unbreakableRangesFit &&
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
    }
  }

  TextPainter _createPainter(double candidate, {bool includeMaxLines = true}) {
    final referenceFontSize = configuration.referenceFontSize;
    final parentStyle = referenceFontSize == 0
        ? configuration.measurementStyle.copyWith(fontSize: candidate)
        : configuration.measurementStyle;
    final text = TextSpan(
      style: parentStyle,
      text: data,
      locale: renderLocale,
      children: measurementTextSpan == null
          ? null
          : <InlineSpan>[measurementTextSpan!],
    );
    return TextPainter(
      text: text,
      textAlign: configuration.textAlign,
      textDirection: configuration.textDirection,
      textScaler: _candidateScaler(candidate),
      maxLines: includeMaxLines ? configuration.maxLines : null,
      ellipsis: configuration.overflow == TextOverflow.ellipsis
          ? '\u2026'
          : null,
      locale: configuration.locale,
      strutStyle: configuration.measurementStrutStyle,
      textWidthBasis: configuration.textWidthBasis,
      textHeightBehavior: configuration.textHeightBehavior,
    );
  }

  TextScaler _candidateScaler(double candidate) {
    final referenceFontSize = configuration.referenceFontSize;
    return referenceFontSize == 0
        ? configuration.userScaler
        : _CandidateTextScaler(
            source: configuration.userScaler,
            candidate: candidate,
            reference: referenceFontSize,
          );
  }
}

double _checkedEffectiveFontSize(
  TextScaler scaler,
  double candidate, {
  required String name,
}) {
  final effectiveFontSize = scaler.scale(candidate);
  _requireFiniteNonNegative(effectiveFontSize, name);
  return _canonicalCandidateZero(effectiveFontSize);
}

final class _CandidateSearchResult {
  const _CandidateSearchResult(this.value, this.fits);

  final double value;
  final bool fits;
}

/// A finite, ascending candidate domain used by the font-size search.
///
/// Regular grids are represented by their bounds, step and index count. Only
/// caller-provided presets are copied; a grid never allocates storage
/// proportional to its numeric range.
final class _CandidateSet {
  _CandidateSet._regular({
    required double minimum,
    required double upper,
    required double step,
    required int regularLength,
    required bool replacesLastRegularWithUpper,
    required this.length,
  }) : _minimum = minimum,
       _upper = upper,
       _step = step,
       _regularLength = regularLength,
       _replacesLastRegularWithUpper = replacesLastRegularWithUpper,
       _presetValues = null;

  _CandidateSet._presets(List<double> values)
    : _minimum = 0,
      _upper = 0,
      _step = 0,
      _regularLength = 0,
      _replacesLastRegularWithUpper = false,
      _presetValues = values,
      length = values.length;

  factory _CandidateSet.regular({
    required double minimum,
    required double upper,
    required double step,
  }) {
    final canonicalMinimum = _canonicalCandidateZero(minimum);
    final canonicalUpper = _canonicalCandidateZero(upper);

    if (canonicalUpper < canonicalMinimum) {
      throw ArgumentError.value(
        upper,
        'upper',
        'must be greater than or equal to minimum',
      );
    }

    // When both exact bounds are indistinguishable at the domain tolerance,
    // the exact upper bound wins. This is the sole exception to retaining the
    // exact minimum and prevents a quasi-duplicate two-value domain.
    if (_candidatesAreNearlyEqual(canonicalMinimum, canonicalUpper)) {
      return _CandidateSet._regular(
        minimum: canonicalMinimum,
        upper: canonicalUpper,
        step: step,
        regularLength: 1,
        replacesLastRegularWithUpper: true,
        length: 1,
      );
    }

    if (canonicalMinimum + step <= canonicalMinimum) {
      throw ArgumentError.value(
        step,
        'stepGranularity',
        'does not advance from minFontSize at floating-point precision',
      );
    }

    final interval = canonicalUpper - canonicalMinimum;
    final ratio = interval / step;
    if (!ratio.isFinite || ratio > _maximumExactCandidateIndex) {
      throw ArgumentError.value(
        ratio,
        'candidateRatio',
        'must have a finite, exactly representable candidate index',
      );
    }

    var lastRegularIndex = ratio.floor();
    var lastRegular = canonicalMinimum + lastRegularIndex * step;
    if (lastRegular > canonicalUpper &&
        !_candidatesAreNearlyEqual(lastRegular, canonicalUpper)) {
      lastRegularIndex -= 1;
      lastRegular = canonicalMinimum + lastRegularIndex * step;
    }

    if (!_candidatesAreNearlyEqual(lastRegular, canonicalUpper)) {
      final nextRegular = canonicalMinimum + (lastRegularIndex + 1) * step;
      if (nextRegular < canonicalUpper ||
          _candidatesAreNearlyEqual(nextRegular, canonicalUpper)) {
        lastRegularIndex += 1;
        lastRegular = nextRegular;
      }
    }

    final regularLength = lastRegularIndex + 1;
    if (regularLength > 2 && step < canonicalUpper * _doubleEpsilon) {
      throw ArgumentError.value(
        step,
        'stepGranularity',
        'cannot produce a strictly increasing floating-point grid',
      );
    }

    final replacesLastRegularWithUpper = _candidatesAreNearlyEqual(
      lastRegular,
      canonicalUpper,
    );
    final length = regularLength + (replacesLastRegularWithUpper ? 0 : 1);
    final candidates = _CandidateSet._regular(
      minimum: canonicalMinimum,
      upper: canonicalUpper,
      step: step,
      regularLength: regularLength,
      replacesLastRegularWithUpper: replacesLastRegularWithUpper,
      length: length,
    );

    if (length > 1 && candidates[1] <= candidates[0]) {
      throw ArgumentError.value(
        step,
        'stepGranularity',
        'cannot produce a strictly increasing floating-point grid',
      );
    }
    if (length > 2 && candidates[length - 1] <= candidates[length - 2]) {
      throw ArgumentError.value(
        step,
        'stepGranularity',
        'cannot produce a strictly increasing floating-point grid',
      );
    }

    return candidates;
  }

  factory _CandidateSet.presets(List<double> presetFontSizes) {
    final snapshot = List<double>.of(presetFontSizes, growable: false);
    if (snapshot.isEmpty) {
      throw ArgumentError.value(
        presetFontSizes,
        'presetFontSizes',
        'must not be empty',
      );
    }

    final canonicalDescending = <double>[];
    double? previous;
    for (final originalValue in snapshot) {
      _requireFiniteNonNegative(originalValue, 'presetFontSizes');
      final value = _canonicalCandidateZero(originalValue);
      if (previous != null && value > previous) {
        throw ArgumentError.value(
          presetFontSizes,
          'presetFontSizes',
          'must be in non-increasing order',
        );
      }
      canonicalDescending.add(value);
      previous = value;
    }

    final uniqueDescending = <double>[];
    for (final value in canonicalDescending) {
      if (uniqueDescending.isEmpty ||
          !_candidatesAreNearlyEqual(value, uniqueDescending.last)) {
        uniqueDescending.add(value);
      }
    }

    final ascending = List<double>.unmodifiable(uniqueDescending.reversed);
    return _CandidateSet._presets(ascending);
  }

  final double _minimum;
  final double _upper;
  final double _step;
  final int _regularLength;
  final bool _replacesLastRegularWithUpper;
  final List<double>? _presetValues;

  final int length;

  double operator [](int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }

    final presetValues = _presetValues;
    if (presetValues != null) {
      return presetValues[index];
    }
    if (index == length - 1 &&
        (_replacesLastRegularWithUpper || index == _regularLength)) {
      return _upper;
    }

    final candidate = _minimum + index * _step;
    if (candidate < _minimum) {
      return _minimum;
    }
    if (candidate > _upper) {
      return _upper;
    }
    return _canonicalCandidateZero(candidate);
  }

  _CandidateSearchResult findLargestThatFits(
    bool Function(double candidate) fits,
  ) {
    var left = 0;
    var right = length - 1;
    var bestIndex = 0;
    var anyCandidateFits = false;

    while (left <= right) {
      final middle = left + (right - left) ~/ 2;
      final candidate = this[middle];
      if (fits(candidate)) {
        bestIndex = middle;
        anyCandidateFits = true;
        left = middle + 1;
      } else {
        right = middle - 1;
      }
    }

    return _CandidateSearchResult(this[bestIndex], anyCandidateFits);
  }
}

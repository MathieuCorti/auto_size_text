part of '../auto_size_text.dart';

/// Flutter widget that automatically resizes text to fit perfectly within its
/// bounds.
///
/// All size constraints as well as maxLines are taken into account. If the text
/// overflows anyway, you should check if the parent widget actually constraints
/// the size of this widget.
class AutoSizeText extends StatefulWidget {
  /// Creates a [AutoSizeText] widget.
  ///
  /// If the [style] argument is null, the text will use the style from the
  /// closest enclosing [DefaultTextStyle].
  const AutoSizeText(
    String this.data, {
    super.key,
    this.textKey,
    this.style,
    this.strutStyle,
    this.minFontSize = 12,
    this.maxFontSize = double.infinity,
    this.stepGranularity = 1,
    this.presetFontSizes,
    this.group,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.wrapWords = true,
    this.overflow,
    this.overflowReplacement,
    @Deprecated('Use textScaler instead.') this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
  }) : assert(
         textScaler == null || textScaleFactor == null,
         'textScaleFactor is deprecated and cannot be specified when '
         'textScaler is specified.',
       ),
       textSpan = null;

  /// Creates a [AutoSizeText] widget with a [TextSpan].
  const AutoSizeText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.textKey,
    this.style,
    this.strutStyle,
    this.minFontSize = 12,
    this.maxFontSize = double.infinity,
    this.stepGranularity = 1,
    this.presetFontSizes,
    this.group,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.wrapWords = true,
    this.overflow,
    this.overflowReplacement,
    @Deprecated('Use textScaler instead.') this.textScaleFactor,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
  }) : assert(
         textScaler == null || textScaleFactor == null,
         'textScaleFactor is deprecated and cannot be specified when '
         'textScaler is specified.',
       ),
       data = null;

  /// Sets the key for the resulting [Text] widget.
  ///
  /// This allows you to find the actual `Text` widget built by `AutoSizeText`.
  final Key? textKey;

  /// The text to display.
  ///
  /// This will be null if a [textSpan] is provided instead.
  final String? data;

  /// The text to display as a [TextSpan].
  ///
  /// This will be null if [data] is provided instead.
  final TextSpan? textSpan;

  /// If non-null, the style to use for this text.
  ///
  /// If the style's "inherit" property is true, the style will be merged with
  /// the closest enclosing [DefaultTextStyle]. Otherwise, the style will
  /// replace the closest enclosing [DefaultTextStyle].
  final TextStyle? style;

  // The default font size if none is specified.
  static const double _defaultFontSize = 14;

  /// The strut style to use. Strut style defines the strut, which sets minimum
  /// vertical layout metrics.
  ///
  /// Omitting or providing null will disable strut.
  ///
  /// Omitting or providing null for any properties of [StrutStyle] will result
  /// in default values being used. It is highly recommended to at least specify
  /// a font size.
  ///
  /// See [StrutStyle] for details.
  final StrutStyle? strutStyle;

  /// The minimum text size constraint to be used when auto-sizing text.
  ///
  /// Is being ignored if [presetFontSizes] is set.
  final double minFontSize;

  /// The maximum text size constraint to be used when auto-sizing text.
  ///
  /// Is being ignored if [presetFontSizes] is set.
  final double maxFontSize;

  /// The step size in which the font size is being adapted to constraints.
  ///
  /// The Text scales uniformly in a range between [minFontSize] and
  /// [maxFontSize].
  /// Each increment occurs as per the step size set in stepGranularity.
  ///
  /// Most of the time you don't want a stepGranularity below 1.0.
  ///
  /// Is being ignored if [presetFontSizes] is set.
  final double stepGranularity;

  /// Predefines all the possible font sizes.
  ///
  /// **Important:** PresetFontSizes have to be in descending order.
  final List<double>? presetFontSizes;

  /// Synchronizes the size of multiple [AutoSizeText]s.
  ///
  /// If you want multiple [AutoSizeText]s to have the same text size, give all
  /// of them the same [AutoSizeGroup] instance. All of them will have the
  /// size of the smallest [AutoSizeText]
  final AutoSizeGroup? group;

  /// How the text should be aligned horizontally.
  final TextAlign? textAlign;

  /// The directionality of the text.
  ///
  /// This decides how [textAlign] values like [TextAlign.start] and
  /// [TextAlign.end] are interpreted.
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the [data] is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// Defaults to the ambient [Directionality], if any.
  final TextDirection? textDirection;

  /// Used to select a font when the same Unicode character can
  /// be rendered differently, depending on the locale.
  ///
  /// It's rarely necessary to set this property. By default its value
  /// is inherited from the enclosing app with `Localizations.localeOf(context)`.
  final Locale? locale;

  /// Whether the text should break at soft line breaks.
  ///
  /// If false, the glyphs in the text will be positioned as if there was
  /// unlimited horizontal space.
  final bool? softWrap;

  /// Whether words which don't fit in one line should be wrapped.
  ///
  /// If false, the fontSize is lowered as far as possible until all words fit
  /// into a single line.
  final bool wrapWords;

  /// How visual overflow should be handled.
  ///
  /// Defaults to retrieving the value from the nearest [DefaultTextStyle] ancestor.
  final TextOverflow? overflow;

  /// If the text is overflowing and does not fit its bounds, this widget is
  /// displayed instead.
  final Widget? overflowReplacement;

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  ///
  /// This property also affects [minFontSize], [maxFontSize] and [presetFontSizes].
  ///
  /// The legacy linear scale supplied to the constructor.
  ///
  /// When null, [textScaler] or the ambient [MediaQuery] scaler is used.
  @Deprecated('Use textScaler instead.')
  final double? textScaleFactor;

  /// The strategy used to scale the text for accessibility.
  ///
  /// When null, [textScaleFactor] is converted to a linear scaler if supplied;
  /// otherwise the ambient [MediaQuery] scaler is used. Custom scalers must be
  /// monotone non-decreasing for the font-size search to remain defined.
  final TextScaler? textScaler;

  /// An optional maximum number of lines for the text to span, wrapping if necessary.
  /// If the text exceeds the given number of lines, it will be resized according
  /// to the specified bounds and if necessary truncated according to [overflow].
  ///
  /// If this is 1, text will not wrap. Otherwise, text will be wrapped at the
  /// edge of the box.
  ///
  /// If this is null, but there is an ambient [DefaultTextStyle] that specifies
  /// an explicit number for its [DefaultTextStyle.maxLines], then the
  /// [DefaultTextStyle] value will take precedence. You can use a [RichText]
  /// widget directly to entirely override the [DefaultTextStyle].
  final int? maxLines;

  /// An alternative semantics label for this text.
  ///
  /// If present, the semantics of this widget will contain this value instead
  /// of the actual text. This will overwrite any of the semantics labels applied
  /// directly to the [TextSpan]s.
  ///
  /// This is useful for replacing abbreviations or shorthands with the full
  /// text value:
  ///
  /// ```dart
  /// AutoSizeText(r'$$', semanticsLabel: 'Double dollars')
  /// ```
  final String? semanticsLabel;

  @override
  State<AutoSizeText> createState() => _AutoSizeTextState();
}

class _AutoSizeTextState extends State<AutoSizeText> {
  double? _publishedEffectiveFontSize;

  @override
  void initState() {
    super.initState();

    widget.group?._register(this);
  }

  @override
  void didUpdateWidget(AutoSizeText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.group, widget.group)) {
      oldWidget.group?._remove(this);
      widget.group?._register(this);
      _publishedEffectiveFontSize = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final configuration = _createEffectiveTextConfiguration(context);
        // ignore: deprecated_member_use_from_same_package
        final legacyTextScaleFactor = widget.textScaleFactor;
        _validateCandidateInputs(
          referenceFontSize: configuration.referenceFontSize,
          textScaleFactor: legacyTextScaleFactor,
        );
        final candidates = _createCandidateSet(configuration.referenceFontSize);
        _validateProperties(configuration.maxLines);

        final result = _calculateFontSize(
          constraints,
          configuration,
          candidates,
        );

        var renderCandidate = result.candidate;
        final group = widget.group;
        if (group != null) {
          if (_publishedEffectiveFontSize != result.effectiveFontSize) {
            group._updateFontSize(this, result.effectiveFontSize);
            _publishedEffectiveFontSize = result.effectiveFontSize;
          }
          renderCandidate = _projectGroupFontSize(
            candidates,
            result.candidate,
            configuration.userScaler,
            group._fontSize,
          );
        }
        final text = _buildText(renderCandidate, configuration);

        if (widget.overflowReplacement != null && !result.fits) {
          return widget.overflowReplacement!;
        }
        return text;
      },
    );
  }

  _EffectiveTextConfiguration _createEffectiveTextConfiguration(
    BuildContext context,
  ) {
    final defaultTextStyle = DefaultTextStyle.of(context);

    var baseStyle = widget.style;
    if (widget.style == null || widget.style!.inherit) {
      baseStyle = defaultTextStyle.style.merge(widget.style);
    }

    final needsDefaultFontSize = baseStyle!.fontSize == null;
    TextStyle? renderStyle = widget.style;
    if (needsDefaultFontSize) {
      baseStyle = baseStyle.copyWith(fontSize: AutoSizeText._defaultFontSize);
      renderStyle = (widget.style ?? const TextStyle()).copyWith(
        fontSize: AutoSizeText._defaultFontSize,
      );
    }

    var measurementStyle = baseStyle;
    if (MediaQuery.boldTextOf(context)) {
      measurementStyle = measurementStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    final lineHeightOverride = MediaQuery.maybeLineHeightScaleFactorOverrideOf(
      context,
    );
    final letterSpacingOverride = MediaQuery.maybeLetterSpacingOverrideOf(
      context,
    );
    final wordSpacingOverride = MediaQuery.maybeWordSpacingOverrideOf(context);
    final measurementTextStyleOverride =
        lineHeightOverride == null &&
            letterSpacingOverride == null &&
            wordSpacingOverride == null
        ? null
        : TextStyle(
            height: lineHeightOverride,
            letterSpacing: letterSpacingOverride,
            wordSpacing: wordSpacingOverride,
          );
    measurementStyle = measurementStyle.merge(
      measurementTextStyleOverride ?? const TextStyle(),
    );

    final measurementStrutStyle = widget.strutStyle?.merge(
      StrutStyle(height: lineHeightOverride),
    );
    final effectiveOverflow =
        widget.overflow ??
        measurementStyle.overflow ??
        defaultTextStyle.overflow;

    return _EffectiveTextConfiguration(
      baseStyle: baseStyle,
      measurementStyle: measurementStyle,
      measurementTextStyleOverride: measurementTextStyleOverride,
      renderStyle: renderStyle,
      measurementStrutStyle: measurementStrutStyle,
      textAlign:
          widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
      textDirection: widget.textDirection ?? Directionality.of(context),
      locale: widget.locale ?? Localizations.maybeLocaleOf(context),
      softWrap: widget.softWrap ?? defaultTextStyle.softWrap,
      overflow: effectiveOverflow,
      maxLines: widget.maxLines ?? defaultTextStyle.maxLines,
      textWidthBasis: defaultTextStyle.textWidthBasis,
      textHeightBehavior:
          defaultTextStyle.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      userScaler: _resolveUserTextScaler(context),
    );
  }

  TextScaler _resolveUserTextScaler(BuildContext context) {
    // ignore: deprecated_member_use_from_same_package
    final legacyTextScaleFactor = widget.textScaleFactor;
    if (widget.textScaler != null && legacyTextScaleFactor != null) {
      throw ArgumentError(
        'textScaler and textScaleFactor cannot both be specified.',
      );
    }
    if (widget.textScaler case final textScaler?) {
      return textScaler;
    }
    if (legacyTextScaleFactor != null) {
      _requireFiniteNonNegative(legacyTextScaleFactor, 'textScaleFactor');
      return TextScaler.linear(_canonicalCandidateZero(legacyTextScaleFactor));
    }
    return MediaQuery.textScalerOf(context);
  }

  void _validateProperties(int? maxLines) {
    assert(
      widget.overflow == null || widget.overflowReplacement == null,
      'Either overflow or overflowReplacement must be null.',
    );
    assert(
      maxLines == null || maxLines > 0,
      'MaxLines must be greater than or equal to 1.',
    );
    assert(
      widget.key == null || widget.key != widget.textKey,
      'Key and textKey must not be equal.',
    );

    if (widget.presetFontSizes == null) {
      assert(
        widget.stepGranularity >= 0.1,
        'StepGranularity must be greater than or equal to 0.1. It is not a '
        'good idea to resize the font with a higher accuracy.',
      );
      assert(
        widget.minFontSize >= 0,
        'MinFontSize must be greater than or equal to 0.',
      );
      assert(widget.maxFontSize > 0, 'MaxFontSize has to be greater than 0.');
      assert(
        widget.minFontSize <= widget.maxFontSize,
        'MinFontSize must be smaller or equal than maxFontSize.',
      );
    } else {
      assert(
        widget.presetFontSizes!.isNotEmpty,
        'PresetFontSizes must not be empty.',
      );
    }
  }

  _CandidateSet _createCandidateSet(double referenceFontSize) {
    final presetFontSizes = widget.presetFontSizes;
    if (presetFontSizes != null) {
      return _CandidateSet.presets(presetFontSizes);
    }

    _validateRegularCandidateInputs(
      minFontSize: widget.minFontSize,
      maxFontSize: widget.maxFontSize,
      stepGranularity: widget.stepGranularity,
    );

    final upper = referenceFontSize
        .clamp(widget.minFontSize, widget.maxFontSize)
        .toDouble();
    return _CandidateSet.regular(
      minimum: widget.minFontSize,
      upper: upper,
      step: widget.stepGranularity,
    );
  }

  _AutoSizeTextLayoutResult _calculateFontSize(
    BoxConstraints constraints,
    _EffectiveTextConfiguration configuration,
    _CandidateSet candidates,
  ) {
    final sourceTextSpan = widget.textSpan;
    if (sourceTextSpan != null && _containsWidgetSpan(sourceTextSpan)) {
      throw UnsupportedError(
        'AutoSizeText.rich does not support WidgetSpan until inline children '
        'receive automatic placeholder dimensions.',
      );
    }
    final measurementTextSpan = sourceTextSpan == null
        ? null
        : _applyTextStyleOverride(
            sourceTextSpan,
            configuration.measurementTextStyleOverride,
          );
    final unbreakableTextSnapshot = widget.wrapWords
        ? null
        : _UnbreakableTextSnapshot.from(
            measurementTextSpan ?? TextSpan(text: widget.data),
          );

    final referenceFontSize = configuration.referenceFontSize;
    final result = candidates.findLargestThatFits((candidate) {
      final parentStyle = referenceFontSize == 0
          ? configuration.measurementStyle.copyWith(fontSize: candidate)
          : configuration.measurementStyle;
      final span = TextSpan(
        style: parentStyle,
        text: widget.data,
        locale: widget.locale,
        children: measurementTextSpan == null
            ? null
            : <InlineSpan>[measurementTextSpan],
      );
      final candidateScaler = referenceFontSize == 0
          ? configuration.userScaler
          : _CandidateTextScaler(
              source: configuration.userScaler,
              candidate: candidate,
              reference: referenceFontSize,
            );
      return _checkTextFits(
        span,
        candidateScaler,
        configuration,
        constraints,
        unbreakableTextSnapshot,
      );
    });

    final effectiveFontSize = _checkedEffectiveFontSize(
      configuration.userScaler,
      result.value,
      name: 'calculatedFontSize',
    );

    return _AutoSizeTextLayoutResult(
      candidate: result.value,
      effectiveFontSize: effectiveFontSize,
      fits: result.fits,
    );
  }

  double _projectGroupFontSize(
    _CandidateSet candidates,
    double localCandidate,
    TextScaler userScaler,
    double groupLimit,
  ) {
    return candidates.findLargestThatFits((candidate) {
      if (candidate > localCandidate) {
        return false;
      }
      final effectiveFontSize = _checkedEffectiveFontSize(
        userScaler,
        candidate,
        name: 'projectedFontSize',
      );
      return effectiveFontSize <= groupLimit;
    }).value;
  }

  bool _checkTextFits(
    TextSpan text,
    TextScaler candidateScaler,
    _EffectiveTextConfiguration configuration,
    BoxConstraints constraints,
    _UnbreakableTextSnapshot? unbreakableTextSnapshot,
  ) {
    if (unbreakableTextSnapshot != null) {
      final wordWrapTextPainter = TextPainter(
        text: text,
        textAlign: configuration.textAlign,
        textDirection: configuration.textDirection,
        textScaler: candidateScaler,
        locale: configuration.locale,
        strutStyle: configuration.measurementStrutStyle,
        textWidthBasis: configuration.textWidthBasis,
        textHeightBehavior: configuration.textHeightBehavior,
      );

      try {
        wordWrapTextPainter.layout(maxWidth: double.infinity);
        for (final range in unbreakableTextSnapshot.ranges) {
          final boxes = wordWrapTextPainter.getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          );
          final rangeWidth = boxes.fold<double>(
            0,
            (width, box) => width + (box.right - box.left).abs(),
          );
          if (rangeWidth > constraints.maxWidth) {
            return false;
          }
        }
      } finally {
        wordWrapTextPainter.dispose();
      }
    }

    final textPainter = TextPainter(
      text: text,
      textAlign: configuration.textAlign,
      textDirection: configuration.textDirection,
      textScaler: candidateScaler,
      maxLines: configuration.maxLines,
      ellipsis: configuration.overflow == TextOverflow.ellipsis
          ? '\u2026'
          : null,
      locale: configuration.locale,
      strutStyle: configuration.measurementStrutStyle,
      textWidthBasis: configuration.textWidthBasis,
      textHeightBehavior: configuration.textHeightBehavior,
    );

    try {
      final layoutMaxWidth =
          configuration.softWrap ||
              configuration.overflow == TextOverflow.ellipsis
          ? constraints.maxWidth
          : double.infinity;
      textPainter.layout(
        minWidth: constraints.minWidth,
        maxWidth: layoutMaxWidth,
      );
      final textSize = textPainter.size;
      final renderSize = constraints.constrain(textSize);

      return !textPainter.didExceedMaxLines &&
          renderSize.width >= textSize.width &&
          renderSize.height >= textSize.height;
    } finally {
      textPainter.dispose();
    }
  }

  Widget _buildText(
    double candidate,
    _EffectiveTextConfiguration configuration,
  ) {
    final referenceFontSize = configuration.referenceFontSize;
    if (widget.data != null) {
      final renderStyle = referenceFontSize == 0
          ? (configuration.renderStyle ?? const TextStyle()).copyWith(
              fontSize: candidate,
            )
          : configuration.renderStyle;
      final candidateScaler = referenceFontSize == 0
          ? configuration.userScaler
          : _CandidateTextScaler(
              source: configuration.userScaler,
              candidate: candidate,
              reference: referenceFontSize,
            );
      return Text(
        widget.data!,
        key: widget.textKey,
        style: renderStyle,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: candidateScaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        textWidthBasis: configuration.textWidthBasis,
        textHeightBehavior: configuration.textHeightBehavior,
      );
    } else {
      final renderStyle = referenceFontSize == 0
          ? (configuration.renderStyle ?? const TextStyle()).copyWith(
              fontSize: candidate,
            )
          : configuration.renderStyle;
      final candidateScaler = referenceFontSize == 0
          ? configuration.userScaler
          : _CandidateTextScaler(
              source: configuration.userScaler,
              candidate: candidate,
              reference: referenceFontSize,
            );
      return Text.rich(
        widget.textSpan!,
        key: widget.textKey,
        style: renderStyle,
        strutStyle: widget.strutStyle,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        locale: widget.locale,
        softWrap: widget.softWrap,
        overflow: widget.overflow,
        textScaler: candidateScaler,
        maxLines: widget.maxLines,
        semanticsLabel: widget.semanticsLabel,
        textWidthBasis: configuration.textWidthBasis,
        textHeightBehavior: configuration.textHeightBehavior,
      );
    }
  }

  void _notifySync() {
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.group != null) {
      widget.group!._remove(this);
    }
    super.dispose();
  }
}

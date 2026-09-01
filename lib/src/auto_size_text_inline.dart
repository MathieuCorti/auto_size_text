part of '../auto_size_text.dart';

final class _AutoSizeInlineText extends StatelessWidget {
  const _AutoSizeInlineText({required this.snapshot, required this.candidate});

  final _AutoSizeTextLayoutSnapshot snapshot;
  final double candidate;

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    final selectionStyle = DefaultSelectionStyle.of(context);
    Widget result = _AutoSizeInlineParagraph(
      text: snapshot.resolvedText(candidate),
      textAlign: snapshot.configuration.textAlign,
      textDirection: snapshot.configuration.textDirection,
      softWrap: snapshot.configuration.softWrap,
      overflow: snapshot.configuration.overflow,
      textScaler: snapshot.candidateScaler(candidate),
      maxLines: snapshot.configuration.maxLines,
      locale: snapshot.configuration.locale,
      strutStyle: snapshot.configuration.measurementStrutStyle,
      textWidthBasis: snapshot.configuration.textWidthBasis,
      textHeightBehavior: snapshot.configuration.textHeightBehavior,
      registrar: registrar,
      selectionColor: registrar == null
          ? null
          : selectionStyle.selectionColor ?? DefaultSelectionStyle.defaultColor,
    );
    if (registrar != null) {
      result = MouseRegion(
        cursor: selectionStyle.mouseCursor ?? SystemMouseCursors.text,
        child: result,
      );
    }
    if (snapshot.semanticsLabel case final label?) {
      result = Semantics(
        textDirection: snapshot.configuration.textDirection,
        label: label,
        child: ExcludeSemantics(child: result),
      );
    }
    return result;
  }
}

final class _AutoSizeInlineParagraph extends MultiChildRenderObjectWidget {
  _AutoSizeInlineParagraph({
    required this.text,
    required this.textAlign,
    required this.textDirection,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.locale,
    required this.strutStyle,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.registrar,
    required this.selectionColor,
  }) : super(children: _extractAutoSizeInlineChildren(text, textScaler));

  final InlineSpan text;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final bool softWrap;
  final TextOverflow overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final SelectionRegistrar? registrar;
  final Color? selectionColor;

  @override
  _RenderAutoSizeInlineParagraph createRenderObject(BuildContext context) {
    return _RenderAutoSizeInlineParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      registrar: registrar,
      selectionColor: selectionColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAutoSizeInlineParagraph renderObject,
  ) {
    renderObject
      ..text = text
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..locale = locale
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..registrar = registrar
      ..selectionColor = selectionColor;
  }
}

List<Widget> _extractAutoSizeInlineChildren(
  InlineSpan root,
  TextScaler scaler,
) {
  final widgets = <Widget>[];
  var semanticsIndex = 0;

  void visit(InlineSpan span, double inheritedFontSize) {
    final runFontSize = span.style?.fontSize ?? inheritedFontSize;
    if (span case final WidgetSpan widgetSpan) {
      widgets.add(
        _AutoSizeInlineParentData(
          span: widgetSpan,
          child: Semantics(
            tagForChildren: PlaceholderSpanIndexSemanticsTag(semanticsIndex++),
            child: _AutoSizeInlineScale(
              runFontSize: runFontSize,
              scale: _inlineScaleFactor(scaler, runFontSize),
              child: widgetSpan.child,
            ),
          ),
        ),
      );
    }
    assert(
      span is WidgetSpan || span is! PlaceholderSpan,
      '$span is a PlaceholderSpan but not a WidgetSpan.',
    );
    span.visitDirectChildren((child) {
      visit(child, runFontSize);
      return true;
    });
  }

  visit(root, root.style?.fontSize ?? kDefaultFontSize);
  return widgets;
}

double _inlineScaleFactor(TextScaler scaler, double runFontSize) {
  if (runFontSize == 0) {
    return 0;
  }
  final scaled = _scaleUserFontSize(
    scaler,
    runFontSize,
    name: 'inlineScaledFontSize',
  );
  final factor = scaled / runFontSize;
  _requireFiniteNonNegative(factor, 'inlineScaleFactor');
  return factor;
}

final class _AutoSizeInlineParentData extends ParentDataWidget<TextParentData> {
  const _AutoSizeInlineParentData({required this.span, required super.child});

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
  Type get debugTypicalAncestorWidgetClass => _AutoSizeInlineParagraph;
}

final class _AutoSizeInlineScale extends SingleChildRenderObjectWidget {
  const _AutoSizeInlineScale({
    required this.runFontSize,
    required this.scale,
    required super.child,
  });

  final double runFontSize;
  final double scale;

  @override
  _RenderAutoSizeInlineScale createRenderObject(BuildContext context) {
    return _RenderAutoSizeInlineScale(runFontSize, scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAutoSizeInlineScale renderObject,
  ) {
    renderObject
      ..runFontSize = runFontSize
      ..scale = scale;
  }
}

final class _RenderAutoSizeInlineScale extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderAutoSizeInlineScale(this._runFontSize, this._scale);

  double _runFontSize;
  set runFontSize(double value) {
    if (value != _runFontSize) {
      _runFontSize = value;
      markNeedsLayout();
    }
  }

  double _scale;
  set scale(double value) {
    if (value != _scale) {
      _requireFiniteNonNegative(value, 'inlineScaleFactor');
      _scale = value;
      markNeedsLayout();
    }
  }

  void configure(TextScaler scaler, double runFontSize) {
    this.runFontSize = runFontSize;
    scale = _inlineScaleFactor(scaler, runFontSize);
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: _scale == 0 ? double.infinity : constraints.maxWidth / _scale,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => Size.zero;

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => 0;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final childBaseline = child?.getDistanceToActualBaseline(baseline);
    return childBaseline == null ? null : childBaseline * _scale;
  }

  @override
  void performLayout() {
    final renderChild = child;
    if (renderChild == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    renderChild.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(
      _scale == 0 ? Size.zero : renderChild.size * _scale,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scaleByDouble(_scale, _scale, _scale, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final renderChild = child;
    if (renderChild == null || _scale == 0) {
      layer = null;
      return;
    }
    if (_scale == 1) {
      context.paintChild(renderChild, offset);
      layer = null;
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, transformedOffset) =>
          context.paintChild(renderChild, transformedOffset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final renderChild = child;
    if (renderChild == null || _scale == 0) {
      return false;
    }
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, transformed) =>
          renderChild.hitTest(result, position: transformed),
    );
  }
}

final class _RenderAutoSizeInlineParagraph extends RenderParagraph {
  _RenderAutoSizeInlineParagraph(
    super.text, {
    required super.textAlign,
    required super.textDirection,
    required super.softWrap,
    required super.overflow,
    required super.textScaler,
    required super.maxLines,
    required super.locale,
    required super.strutStyle,
    required super.textWidthBasis,
    required super.textHeightBehavior,
    required super.registrar,
    required super.selectionColor,
  });

  void configureCandidate(InlineSpan candidateText, TextScaler scaler) {
    text = candidateText;
    textScaler = scaler;
    final runFontSizes = _inlineRunFontSizes(candidateText);
    var index = 0;
    for (RenderBox? host = firstChild; host != null; host = childAfter(host)) {
      _findInlineScale(host).configure(scaler, runFontSizes[index]);
      index += 1;
    }
    if (index != runFontSizes.length) {
      throw StateError('Inline child and WidgetSpan counts differ.');
    }
  }

  List<PlaceholderDimensions> wetPlaceholderDimensions() {
    final dimensions = <PlaceholderDimensions>[];
    for (RenderBox? host = firstChild; host != null; host = childAfter(host)) {
      final span = (host.parentData! as TextParentData).span!;
      dimensions.add(
        PlaceholderDimensions(
          size: host.size,
          alignment: span.alignment,
          baseline: span.baseline,
          baselineOffset: span.alignment == ui.PlaceholderAlignment.baseline
              ? 0
              : null,
        ),
      );
    }
    return dimensions;
  }

  _RenderAutoSizeInlineScale _findInlineScale(RenderBox root) {
    RenderBox current = root;
    while (current is! _RenderAutoSizeInlineScale) {
      if (current case final RenderProxyBox proxy when proxy.child != null) {
        current = proxy.child!;
      } else {
        throw StateError('Missing inline scaling wrapper.');
      }
    }
    return current;
  }
}

List<double> _inlineRunFontSizes(InlineSpan root) {
  final result = <double>[];

  void visit(InlineSpan span, double inheritedFontSize) {
    final runFontSize = span.style?.fontSize ?? inheritedFontSize;
    if (span is WidgetSpan) {
      result.add(runFontSize);
    }
    span.visitDirectChildren((child) {
      visit(child, runFontSize);
      return true;
    });
  }

  visit(root, root.style?.fontSize ?? kDefaultFontSize);
  return result;
}

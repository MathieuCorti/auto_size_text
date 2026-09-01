part of '../auto_size_text.dart';

/// The layout-time boundary that keeps replacement widgets strictly lazy.
final class _AutoSizeTextRenderWidget extends RenderObjectWidget {
  const _AutoSizeTextRenderWidget({
    required this.snapshot,
    required this.overflowReplacement,
    required this.onLayout,
  });

  final _AutoSizeTextLayoutSnapshot snapshot;
  final Widget? overflowReplacement;
  final ValueChanged<double> onLayout;

  Widget childFor(_AutoSizeTextSelection selection) {
    final replacement = overflowReplacement;
    if (replacement != null && !selection.localFits) {
      return replacement;
    }
    return snapshot.buildParagraph(selection.renderCandidate);
  }

  Widget paragraphFor(double candidate) => snapshot.buildParagraph(candidate);

  @override
  RenderObjectElement createElement() => _AutoSizeTextRenderElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderAutoSizeText(snapshot: snapshot, onLayout: onLayout);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAutoSizeText renderObject,
  ) {
    renderObject
      ..snapshot = snapshot
      ..onLayout = onLayout;
  }
}

/// Minimal element used only to exchange the active child during wet layout.
final class _AutoSizeTextRenderElement extends RenderObjectElement {
  _AutoSizeTextRenderElement(_AutoSizeTextRenderWidget super.widget);

  Element? _child;
  final GlobalKey _replacementKey = GlobalKey();

  @override
  _RenderAutoSizeText get renderObject =>
      super.renderObject as _RenderAutoSizeText;

  @override
  void visitChildren(ElementVisitor visitor) {
    final child = _child;
    if (child != null) {
      visitor(child);
    }
  }

  @override
  void forgetChild(Element child) {
    if (child == _child) {
      _child = null;
    }
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject
      ..layoutCallback = _rebuildChild
      ..paragraphLayoutCallback = _rebuildParagraph
      ..layoutFailureCallback = _clearChild;
  }

  @override
  void update(_AutoSizeTextRenderWidget newWidget) {
    super.update(newWidget);
    renderObject
      ..layoutCallback = _rebuildChild
      ..paragraphLayoutCallback = _rebuildParagraph
      ..layoutFailureCallback = _clearChild;
  }

  @override
  void unmount() {
    renderObject
      ..layoutCallback = null
      ..paragraphLayoutCallback = null
      ..layoutFailureCallback = null;
    super.unmount();
  }

  void _rebuildChild(_AutoSizeTextSelection selection) {
    owner!.buildScope(this, () {
      final renderWidget = widget as _AutoSizeTextRenderWidget;
      final keepsReplacement =
          renderWidget.overflowReplacement != null && !selection.localFits;
      final nextWidget = keepsReplacement
          ? KeyedSubtree(
              key: _replacementKey,
              child: renderWidget.childFor(selection),
            )
          : renderWidget.childFor(selection);
      _child = updateChild(_child, nextWidget, null);
    });
  }

  void _rebuildParagraph(double candidate) {
    owner!.buildScope(this, () {
      final renderWidget = widget as _AutoSizeTextRenderWidget;
      _child = updateChild(_child, renderWidget.paragraphFor(candidate), null);
    });
  }

  void _clearChild() {
    owner!.buildScope(this, () {
      _child = updateChild(_child, null, null);
    });
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot == null);
    assert(child is RenderBox);
    renderObject.child = child as RenderBox;
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot == null);
    assert(renderObject.child == child);
    renderObject.child = null;
  }
}

final class _RenderAutoSizeText extends RenderProxyBox {
  _RenderAutoSizeText({
    required _AutoSizeTextLayoutSnapshot snapshot,
    required ValueChanged<double> onLayout,
  }) : _snapshot = snapshot,
       _onLayout = onLayout;

  _AutoSizeTextLayoutSnapshot _snapshot;
  set snapshot(_AutoSizeTextLayoutSnapshot value) {
    if (identical(value, _snapshot)) {
      return;
    }
    _snapshot = value;
    markNeedsLayout();
  }

  ValueChanged<double> _onLayout;
  set onLayout(ValueChanged<double> value) {
    _onLayout = value;
  }

  ValueChanged<_AutoSizeTextSelection>? layoutCallback;
  ValueChanged<double>? paragraphLayoutCallback;
  VoidCallback? layoutFailureCallback;

  @override
  void performLayout() {
    late final _AutoSizeTextSelection selection;
    try {
      if (_snapshot.hasWidgetSpans) {
        invokeLayoutCallback<BoxConstraints>((_) {
          paragraphLayoutCallback?.call(_snapshot.minimumCandidate);
        });
        final paragraphHost = child;
        if (paragraphHost == null) {
          throw StateError('The inline paragraph was not mounted for layout.');
        }
        final paragraph = _findInlineParagraph(paragraphHost);
        selection = _snapshot.selectWet(constraints, paragraphHost, paragraph, (
          candidate,
        ) {
          invokeLayoutCallback<BoxConstraints>((_) {
            paragraph.configureCandidate(
              _snapshot.resolvedText(candidate),
              _snapshot.candidateScaler(candidate),
            );
          });
        });
      } else {
        selection = _snapshot.select(constraints);
      }
    } on _AutoSizeTextUserScalerFailure catch (failure) {
      _reportWetLayoutFailure(failure.original, failure.originalStackTrace);
      return;
    } catch (error, stackTrace) {
      _reportWetLayoutFailure(error, stackTrace);
      return;
    }
    invokeLayoutCallback<BoxConstraints>((_) {
      layoutCallback?.call(selection);
    });

    final renderChild = child;
    if (renderChild == null) {
      size = constraints.smallest;
    } else {
      renderChild.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(renderChild.size);
    }
    _onLayout(selection.localEffectiveFontSize);
  }

  _RenderAutoSizeInlineParagraph _findInlineParagraph(RenderBox root) {
    RenderBox current = root;
    while (current is! _RenderAutoSizeInlineParagraph) {
      if (current case final RenderProxyBox proxy when proxy.child != null) {
        current = proxy.child!;
      } else {
        throw StateError('The inline paragraph was not mounted for layout.');
      }
    }
    return current;
  }

  void _reportWetLayoutFailure(Object error, StackTrace stackTrace) {
    invokeLayoutCallback<BoxConstraints>((_) {
      layoutFailureCallback?.call();
    });
    size = constraints.smallest;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'auto_size_text',
        context: ErrorDescription('while measuring an AutoSizeText'),
      ),
    );
  }

  T _recoverUserScalerFailure<T>({
    required T Function() compute,
    required T fallback,
    required String operation,
  }) {
    try {
      return compute();
    } on _AutoSizeTextUserScalerFailure catch (failure) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: failure.original,
          stack: failure.originalStackTrace,
          library: 'auto_size_text',
          context: ErrorDescription('while $operation for an AutoSizeText'),
        ),
      );
      return fallback;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _recoverUserScalerFailure(
      compute: () => _snapshot.select(constraints).measurement.renderSize,
      fallback: constraints.constrain(Size.zero),
      operation: 'computing dry layout',
    );
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    // RenderParagraph's dry baseline is its alphabetic paragraph baseline for
    // both TextBaseline values. Match that public render-object contract.
    return _recoverUserScalerFailure<double?>(
      compute: () => _snapshot.select(constraints).measurement.baseline,
      fallback: null,
      operation: 'computing a dry baseline',
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _recoverUserScalerFailure(
      compute: () => _snapshot
          .select(BoxConstraints(maxHeight: height))
          .measurement
          .minIntrinsicWidth,
      fallback: 0,
      operation: 'computing minimum intrinsic width',
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _recoverUserScalerFailure(
      compute: () => _snapshot
          .select(BoxConstraints(maxHeight: height))
          .measurement
          .maxIntrinsicWidth,
      fallback: 0,
      operation: 'computing maximum intrinsic width',
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _recoverUserScalerFailure(
      compute: () {
        final selection = _snapshot.select(BoxConstraints(maxWidth: width));
        return _snapshot.intrinsicHeight(selection.renderCandidate, width);
      },
      fallback: 0,
      operation: 'computing minimum intrinsic height',
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _recoverUserScalerFailure(
      compute: () {
        final selection = _snapshot.select(BoxConstraints(maxWidth: width));
        return _snapshot.intrinsicHeight(selection.renderCandidate, width);
      },
      fallback: 0,
      operation: 'computing maximum intrinsic height',
    );
  }
}

/// Keeps [textKey] on the element whose render object is the paragraph.
final class _AutoSizeTextParagraph extends StatelessWidget {
  const _AutoSizeTextParagraph({super.key, required this.child});

  final Widget child;

  @override
  StatelessElement createElement() => _AutoSizeTextParagraphElement(this);

  @override
  Widget build(BuildContext context) => child;
}

final class _AutoSizeTextParagraphElement extends StatelessElement {
  _AutoSizeTextParagraphElement(_AutoSizeTextParagraph super.widget);

  @override
  RenderObject? get renderObject {
    RenderParagraph? paragraph;
    void findParagraph(Element element) {
      if (paragraph != null) {
        return;
      }
      if (element case final RenderObjectElement renderElement) {
        final renderObject = renderElement.renderObject;
        if (renderObject is RenderParagraph) {
          paragraph = renderObject;
          return;
        }
      }
      element.visitChildElements(findParagraph);
    }

    visitChildElements(findParagraph);
    return paragraph ?? super.renderObject;
  }
}

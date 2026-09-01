part of '../auto_size_text.dart';

/// Synchronizes the effective font sizes of multiple [AutoSizeText] widgets.
class AutoSizeGroup {
  /// Creates a group that can be shared by multiple [AutoSizeText] widgets.
  AutoSizeGroup();

  final _listeners = <_AutoSizeTextState, double>{};
  var _notificationPending = false;
  var _fontSize = double.infinity;

  void _register(_AutoSizeTextState text) {
    _listeners[text] = double.infinity;
  }

  void _updateFontSize(_AutoSizeTextState text, double maxFontSize) {
    assert(_listeners.containsKey(text));
    final oldFontSize = _fontSize;
    final previousReport = _listeners[text]!;
    _listeners[text] = maxFontSize;

    if (maxFontSize < _fontSize) {
      _fontSize = maxFontSize;
    } else if (previousReport == _fontSize && maxFontSize > previousReport) {
      _recalculateFontSize();
    }

    if (oldFontSize != _fontSize) {
      _scheduleNotification();
    }
  }

  void _recalculateFontSize() {
    _fontSize = double.infinity;
    for (final size in _listeners.values) {
      if (size < _fontSize) {
        _fontSize = size;
      }
    }
  }

  void _scheduleNotification() {
    if (_notificationPending || _listeners.isEmpty) {
      return;
    }
    _notificationPending = true;
    scheduleMicrotask(_notifyListeners);
  }

  void _notifyListeners() {
    _notificationPending = false;
    final currentListeners = List<_AutoSizeTextState>.of(_listeners.keys);
    for (final textState in currentListeners) {
      if (_listeners.containsKey(textState) && textState.mounted) {
        textState._notifySync();
      }
    }
  }

  void _remove(_AutoSizeTextState text) {
    final oldFontSize = _fontSize;
    final removedReport = _listeners.remove(text);
    if (removedReport == null) {
      return;
    }
    if (removedReport != double.infinity && removedReport == _fontSize) {
      _recalculateFontSize();
    }
    if (oldFontSize != _fontSize) {
      _scheduleNotification();
    }
  }
}

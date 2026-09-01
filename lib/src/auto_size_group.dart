part of '../auto_size_text.dart';

/// Controller to synchronize the fontSize of multiple AutoSizeTexts.
class AutoSizeGroup {
  final _listeners = <_AutoSizeTextState, double>{};
  var _notificationPending = false;
  var _fontSize = double.infinity;

  void _register(_AutoSizeTextState text) {
    _listeners[text] = double.infinity;
  }

  void _updateFontSize(_AutoSizeTextState text, double maxFontSize) {
    assert(_listeners.containsKey(text));
    final oldFontSize = _fontSize;
    _listeners[text] = maxFontSize;
    _recalculateFontSize();

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
    if (_listeners.remove(text) == null) {
      return;
    }
    _recalculateFontSize();
    if (oldFontSize != _fontSize) {
      _scheduleNotification();
    }
  }
}

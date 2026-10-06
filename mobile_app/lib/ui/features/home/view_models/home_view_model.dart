import 'package:flutter/foundation.dart';

/// ViewModel for the Home feature.
///
/// Follows the MVVM pattern: it owns presentation state, exposes an
/// immutable view of it and notifies listeners on every mutation.
/// Repositories would be injected through the constructor once the
/// Data layer is implemented.
class HomeViewModel extends ChangeNotifier {
  int _tapCount = 0;

  /// Number of times the demo counter has been incremented.
  int get tapCount => _tapCount;

  /// Whether [reset] should be enabled in the UI.
  bool get canReset => _tapCount > 0;

  /// Increments the demo counter.
  void increment() {
    _tapCount++;
    notifyListeners();
  }

  /// Resets the demo counter back to zero.
  void reset() {
    if (_tapCount == 0) return;
    _tapCount = 0;
    notifyListeners();
  }
}

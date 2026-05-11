import 'package:flutter/foundation.dart';

class NetworkActivityNotifier extends ChangeNotifier {
  int _pendingRequests = 0;

  bool get isLoading => _pendingRequests > 0;

  void startRequest() {
    _pendingRequests++;
    notifyListeners();
  }

  void finishRequest() {
    if (_pendingRequests <= 0) {
      _pendingRequests = 0;
      return;
    }

    _pendingRequests--;
    notifyListeners();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Theo dõi trạng thái internet realtime cho toàn app.
class InternetStatusService {
  InternetStatusService._();

  static final InternetStatusService instance = InternetStatusService._();

  final InternetConnection _internetConnection = InternetConnection();
  final ValueNotifier<bool> hasInternet = ValueNotifier<bool>(false);

  StreamSubscription<InternetStatus>? _subscription;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    _internetConnection.hasInternetAccess.then((value) {
      hasInternet.value = value;
    });

    _subscription = _internetConnection.onStatusChange.listen((status) {
      hasInternet.value = status == InternetStatus.connected;
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}

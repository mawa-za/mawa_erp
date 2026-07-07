import 'package:flutter/material.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  bool _isMonitoring = false;

  void startMonitoring() {
    _isMonitoring = true;
    debugPrint('SessionService: inactivity timeout disabled for mawa_erp');
  }

  void stopMonitoring() {
    _isMonitoring = false;
    debugPrint('SessionService: monitoring stopped');
  }

  void userActivityDetected() {
    if (!_isMonitoring) return;
    // Screen/session timeout has been intentionally disabled for mawa_erp.
  }
}

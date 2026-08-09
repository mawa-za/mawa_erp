import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../api_client.dart';
import 'setting_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _inactivityTimer;
  int _timeoutSeconds = 600;
  bool _isMonitoring = false;

  void startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    ApiClient().startTokenKeepAlive();

    await _updateTimeoutFromSettings();
    _resetTimer();
    debugPrint(
      'SessionService: Started monitoring with $_timeoutSeconds second timeout',
    );
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _inactivityTimer?.cancel();
    ApiClient().stopTokenKeepAlive();
    debugPrint('SessionService: Stopped monitoring');
  }

  Future<void> _updateTimeoutFromSettings() async {
    try {
      final settings = await SettingService().getSettings();
      final timeoutSetting = settings.firstWhere(
        (setting) => setting.attribute == 'INACTIVE-TIMEOUT',
        orElse: () => settings.firstWhere(
          (setting) => setting.attribute == 'TIMEOUT',
          orElse: () => throw AppException('No timeout setting found'),
        ),
      );

      final value = int.tryParse(timeoutSetting.value.trim());
      if (value != null) {
        _timeoutSeconds = value.clamp(0, 86400).toInt();
      }
    } catch (error) {
      debugPrint(
        'SessionService: Using default timeout of $_timeoutSeconds seconds '
        '($error)',
      );
    }
  }

  void userActivityDetected() {
    if (!_isMonitoring) return;
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    if (_timeoutSeconds <= 0) return;
    _inactivityTimer = Timer(
      Duration(seconds: _timeoutSeconds),
      _handleTimeout,
    );
  }

  void _handleTimeout() {
    if (!_isMonitoring) return;
    debugPrint(
      'SessionService: Inactivity timeout reached '
      '($_timeoutSeconds seconds)',
    );
    ApiClient().logout(sessionExpired: true);
  }
}

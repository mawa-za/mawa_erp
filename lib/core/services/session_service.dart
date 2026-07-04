import 'dart:async';
import 'package:flutter/material.dart';
import 'setting_service.dart';
import '../api_client.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _inactivityTimer;
  int _timeoutMinutes = 30; // Default
  bool _isMonitoring = false;

  void startMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    await _updateTimeoutFromSettings();
    _resetTimer();
    debugPrint('SessionService: Started monitoring with $_timeoutMinutes min timeout');
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _inactivityTimer?.cancel();
    debugPrint('SessionService: Stopped monitoring');
  }

  Future<void> _updateTimeoutFromSettings() async {
    try {
      final settings = await SettingService().getSettings();
      // Try to find INACTIVE-TIMEOUT attribute
      final timeoutSetting = settings.firstWhere(
        (s) => s.attribute == 'INACTIVE-TIMEOUT',
        orElse: () => settings.firstWhere(
          (s) => s.attribute == 'TIMEOUT', 
          orElse: () => throw Exception('No timeout setting found')
        ),
      );
      
      final rawValue = int.tryParse(timeoutSetting.value);
      if (rawValue != null && rawValue > 0) {
        // Legacy MAWA settings have been maintained both as minutes and seconds.
        // Values greater than 60 are treated as seconds, e.g. 360 = 6 minutes.
        _timeoutMinutes = rawValue > 60 ? (rawValue / 60).ceil() : rawValue;
      }
    } catch (e) {
      debugPrint('SessionService: Using default timeout of $_timeoutMinutes minutes ($e)');
    }
  }

  void userActivityDetected() {
    if (!_isMonitoring) return;
    _resetTimer();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), _handleTimeout);
  }

  void _handleTimeout() {
    if (!_isMonitoring) return;
    debugPrint('SessionService: Inactivity timeout reached ($_timeoutMinutes minutes)');
    ApiClient().logout(reason: 'inactivity_timeout');
  }
}

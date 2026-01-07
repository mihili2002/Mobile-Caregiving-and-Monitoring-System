import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class SessionTimeoutService {
  static const Duration _sessionTimeout = Duration(minutes: 30);
  Timer? _sessionTimer;
  final AuthService _authService = AuthService();
  VoidCallback? _onTimeoutCallback;

  /// Initialize session timeout monitoring
  /// [onTimeout] - callback triggered when session expires
  void startSessionTimeout({required VoidCallback onTimeout}) {
    _onTimeoutCallback = onTimeout;
    _resetSessionTimer();
  }

  /// Reset the session timer (call on user activity)
  void resetSessionTimer() {
    _resetSessionTimer();
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, _handleSessionTimeout);
  }

  Future<void> _handleSessionTimeout() async {
    try {
      await _authService.signOut();
      _onTimeoutCallback?.call();
    } catch (e) {
      print('Error during session timeout logout: $e');
    }
  }

  /// Stop monitoring session timeout
  void stopSessionTimeout() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Dispose the service
  void dispose() {
    stopSessionTimeout();
  }
}

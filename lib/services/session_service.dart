import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  
  Timer? _inactivityTimer;
  final Duration _inactivityTimeout = const Duration(minutes: 30);
  final AuthService _authService = AuthService();
  VoidCallback? _onSessionExpired;

  factory SessionService() {
    return _instance;
  }

  SessionService._internal();

  /// Initialize session monitoring
  void initializeSession(VoidCallback onSessionExpired) {
    _onSessionExpired = onSessionExpired;
    _startInactivityTimer();
  }

  /// Reset the inactivity timer (call on user interaction)
  void resetSessionTimer() {
    _inactivityTimer?.cancel();
    _startInactivityTimer();
  }

  /// Start the inactivity timer
  void _startInactivityTimer() {
    _inactivityTimer = Timer(_inactivityTimeout, _handleSessionExpired);
  }

  /// Handle session expiration
  Future<void> _handleSessionExpired() async {
    try {
      await _authService.signOut();
      _onSessionExpired?.call();
    } catch (e) {
      print('Error during auto logout: $e');
    }
  }

  /// Dispose and cleanup
  void dispose() {
    _inactivityTimer?.cancel();
  }

  /// Cancel the current session (manual logout)
  void cancelSession() {
    _inactivityTimer?.cancel();
  }
}

import 'package:flutter/material.dart';
import '../services/session_service.dart';

class SessionWrapper extends StatefulWidget {
  final Widget child;

  const SessionWrapper({super.key, required this.child});

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> {
  late SessionService _sessionService;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService();
    
    // Initialize session with callback
    _sessionService.initializeSession(() {
      _showSessionExpiredDialog();
    });
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired due to inactivity. Please log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // The app will automatically navigate to login via RoleBasedWrapper
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with GestureDetector to detect user interactions
    return GestureDetector(
      onTap: () => _sessionService.resetSessionTimer(),
      onDoubleTap: () => _sessionService.resetSessionTimer(),
      onLongPress: () => _sessionService.resetSessionTimer(),
      onPanDown: (_) => _sessionService.resetSessionTimer(),
      onPanUpdate: (_) => _sessionService.resetSessionTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';

class SetupRequiredPage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onSetupPressed;

  const SetupRequiredPage({
    Key? key,
    required this.title,
    required this.message,
    required this.onSetupPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.error_outline, size: 64, color: Colors.orange),
               const SizedBox(height: 24),
               Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
               const SizedBox(height: 16),
               Text(message, textAlign: TextAlign.center),
               const SizedBox(height: 32),
               ElevatedButton(
                 onPressed: onSetupPressed,
                 child: const Text('Back to Login'),
               )
             ],
          ),
        ),
      ),
    );
  }
}

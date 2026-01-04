import 'package:flutter/material.dart';

class SetupRequiredPage extends StatelessWidget {
  static const routeName = '/setup-required';

  final String title;
  final String message;
  final VoidCallback? onSetupPressed;

  const SetupRequiredPage({
    super.key,
    this.title = 'Setup Required',
    this.message = 'Please complete initial setup before continuing.',
    this.onSetupPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 72, color: Colors.orange),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onSetupPressed ??
                    () {
                      // Default action: navigate to a setup route named '/setup'
                      Navigator.of(context).pushNamed('/setup');
                    },
                child: const Text('Start Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
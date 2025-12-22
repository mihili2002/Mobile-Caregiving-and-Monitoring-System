import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../PatientHealthDetailsScreen.dart';
import '../ElderDashboardScreen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  String role = 'patient'; // default
  String? error;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),

            const SizedBox(height: 16),

            // ROLE SELECTION
            DropdownButton<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patient')),
                DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
              ],
              onChanged: (value) {
                setState(() {
                  role = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        error = null;
                      });

                      try {
                        final user = await authService.register(
                          emailController.text.trim(),
                          passwordController.text.trim(),
                        );

                        // 🔑 SAVE ROLE
                        await user!.updateDisplayName(role);
                        await user.reload();

                        // If registering a patient, immediately show health details form
                        if (role == 'patient') {
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PatientHealthDetailsScreen()),
                          );
                        } else {
                          // For other roles, open the elder dashboard placeholder
                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const ElderDashboardScreen()),
                          );
                        }

                      } catch (e) {
                        setState(() {
                          error = e.toString();
                        });
                      } finally {
                        setState(() {
                          loading = false;
                        });
                      }
                    },
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Create Account'),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

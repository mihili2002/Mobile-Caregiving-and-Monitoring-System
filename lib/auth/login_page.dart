import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  String? error;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
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
                        // 1️⃣ Sign in
                        final user = await authService.signIn(
                          emailController.text.trim(),
                          passwordController.text.trim(),
                        );

                        if (user == null) {
                          throw Exception("Login failed");
                        }

                        // 2️⃣ Get a FRESH Firebase ID token
                        final token = await FirebaseAuth.instance
                            .currentUser!
                            .getIdToken(true);

                        if (token == null) {
                        throw Exception("Failed to retrieve Firebase ID token");
                        }

                        // 3️⃣ Copy token DIRECTLY to clipboard (NO wrapping)
                        await Clipboard.setData(
                          ClipboardData(text: token),
                        );

                        // 4️⃣ Confirmation (do NOT print token)
                        debugPrint('Firebase ID token copied to clipboard');

                        // OPTIONAL: Navigate to next screen here
                        // Navigator.pushReplacement(...);

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
                  : const Text('Login'),
            ),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterPage(),
                  ),
                );
              },
              child: const Text('Create a new account'),
            ),
          ],
        ),
      ),
    );
  }
}

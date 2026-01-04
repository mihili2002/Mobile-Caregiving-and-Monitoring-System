import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'register_page.dart';

// ✅ add these imports
import '../models/user_model.dart';
import '../ElderDashboardScreen.dart';

// ✅ NEW imports for token copy + debug print
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../pages/doctor/doctor_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  String? error;
  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // ---------------------------------------------------
      // ✅ 1) Firebase sign-in (get User back)
      // ---------------------------------------------------
      final User? user = await authService.signIn(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Login failed (Firebase user is null)");
      }

      // ---------------------------------------------------
      // ✅ 2) Force refresh token so custom claims appear
      // ---------------------------------------------------
      final tokenResult = await user.getIdTokenResult(true);

      // ✅ DEBUG ONLY: print role claims + token
      if (kDebugMode) {
        debugPrint("✅ Firebase Claims => ${tokenResult.claims}");
        debugPrint("✅ Firebase Token  => ${tokenResult.token}");
      }

      // ---------------------------------------------------
      // ✅ 3) Copy token to clipboard for Swagger testing
      // ---------------------------------------------------
      final token = tokenResult.token;
      if (token != null && token.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: token));

        if (kDebugMode) {
          debugPrint("✅ Token copied to clipboard");
        }
      }

      // ---------------------------------------------------
      // ✅ 4) Fetch AppUser from Firestore
      // ---------------------------------------------------
      final AppUser? appUser = await authService.getCurrentAppUser();

      if (appUser == null) {
        throw Exception(
          "User profile not found in Firestore. "
          "You may have registered in Firebase Auth but didn't save the user document.",
        );
      }

      if (!mounted) return;

      // ---------------------------------------------------
      // ✅ 5) Navigate based on role
      // ---------------------------------------------------
      if (appUser.role == UserRole.elder) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ElderDashboard(user: appUser),
          ),
        );
      } else if (appUser.role == UserRole.doctor) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DoctorDashboardPage(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logged in as ${appUser.role.name}"),
          ),
        );
      }

    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Same palette + feel as RegisterPage
    const brown = Color(0xFF4E342E);
    const brownDark = Color(0xFF3E2723);
    const bgTop = Color(0xFFF7F3F0);
    const bgBottom = Color(0xFFF2EEF5);

    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // Logo + App name
                    Column(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6D4C41), Color(0xFF8D6E63)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ElderCare',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: brownDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Welcome Back',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: brownDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    _SoftField(
                      controller: usernameController,
                      hintText: 'Username',
                      icon: Icons.person_outline,
                      enabled: !loading,
                      brown: brown,
                    ),
                    const SizedBox(height: 12),

                    _SoftField(
                      controller: passwordController,
                      hintText: 'Password',
                      icon: Icons.lock_outline,
                      enabled: !loading,
                      brown: brown,
                      obscureText: !showPassword,
                      suffix: IconButton(
                        tooltip: showPassword ? 'Hide password' : 'Show password',
                        onPressed: loading
                            ? null
                            : () => setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword ? Icons.visibility_off : Icons.visibility,
                          color: brown.withOpacity(0.7),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brownDark,
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: brownDark.withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ).copyWith(
                          backgroundColor: WidgetStateProperty.resolveWith((_) {
                            return Colors.transparent;
                          }),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFF3E2723), Color(0xFF6D4C41)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.black.withOpacity(0.6)),
                        ),
                        GestureDetector(
                          onTap: loading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  );
                                },
                          child: Text(
                            'Sign up',
                            style: TextStyle(
                              color: brownDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Container(
                      height: 96,
                      margin: const EdgeInsets.symmetric(horizontal: 70),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.health_and_safety,
                          color: brown.withOpacity(0.55),
                          size: 44,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final Color brown;
  final bool obscureText;
  final Widget? suffix;

  const _SoftField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.enabled,
    required this.brown,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        hintText: hintText,
        prefixIcon: Icon(icon, color: brown.withOpacity(0.8)),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

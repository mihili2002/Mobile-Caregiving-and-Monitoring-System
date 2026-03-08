import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'register_page.dart';

import '../models/user_model.dart';
import '../ElderDashboardScreen.dart';

import '../pages/doctor/doctor_dashboard_page.dart';
import '../pages/therapist/therapist_dashboard.dart';
import '../pages/caregiver/caregiver_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  String? error;
  bool loading = false;
  bool showPassword = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final User? user = await authService.signIn(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Login failed (Firebase user is null)");
      }

      await user.getIdTokenResult(true);

      final AppUser? appUser = await authService.getCurrentAppUser();

      if (appUser == null) {
        throw Exception("User profile not found in Firestore.");
      }

      if (!mounted) return;

      if (appUser.role == UserRole.elder) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ElderDashboard(user: appUser)),
        );
      } else if (appUser.role == UserRole.caregiver) {
        //  FIX: caregiver now navigates correctly
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CaregiverDashboard(user: appUser)),
        );
      } else if (appUser.role == UserRole.doctor) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorDashboardPage()),
        );
      } else if (appUser.role == UserRole.therapist) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TherapistDashboard(user: appUser)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brownDark = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Abstract Shapes
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE0F2F1),
                    const Color(0xFFB2EBF2).withOpacity(0.6),
                    const Color(0xFFE0F2F1),
                  ],
                ),
              ),
            ),
          ),

          // Abstract circles for depth
          Positioned(
            top: -100,
            right: -50,
            child: _BlurredCircle(
              color: brownDark.withOpacity(0.12),
              size: 300,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: _BlurredCircle(
              color: const Color(0xFF00BBA7).withOpacity(0.08),
              size: 250,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Logo Section
                          _buildLogo(brownDark),

                          const SizedBox(height: 32),

                          // Glassmorphism Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeader(theme, brownDark),
                                    const SizedBox(height: 28),
                                    if (error != null) _buildErrorBox(),
                                    _buildTextFields(brownDark),
                                    const SizedBox(height: 32),
                                    _buildLoginButton(brownDark),
                                    const SizedBox(height: 24),
                                    _buildSignUpLink(brownDark),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Bottom Icon
                          Opacity(
                            opacity: 0.4,
                            child: Icon(
                              Icons.health_and_safety_rounded,
                              color: brownDark,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.favorite_rounded, color: color, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'eldease',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your account',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFields(Color color) {
    return Column(
      children: [
        TextField(
          controller: usernameController,
          enabled: !loading,
          decoration: InputDecoration(
            hintText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined, size: 22, color: color.withOpacity(0.7)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          enabled: !loading,
          obscureText: !showPassword,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 22, color: color.withOpacity(0.7)),
            suffixIcon: IconButton(
              onPressed: () => setState(() => showPassword = !showPassword),
              icon: Icon(
                showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
                color: color.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(Color color) {
    return Hero(
      tag: 'auth_button',
      child: ElevatedButton(
        onPressed: loading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Sign In'),
      ),
    );
  }

  Widget _buildSignUpLink(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "New to Eldease? ",
          style: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w500),
        ),
        GestureDetector(
          onTap: loading
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
          child: Text(
            'Create account',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurredCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

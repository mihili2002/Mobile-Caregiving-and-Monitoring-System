import 'dart:ui';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/session_wrapper.dart';
import '../widgets/auth_wrapper.dart';
import '../pages/elder/onboarding_flow.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();

  String role = 'elder';
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

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = await authService.register(
        usernameController.text.trim(),
        passwordController.text.trim(),
      );

      if (user != null) {
        UserRole userRole;
        switch (role) {
          case 'elder':
            userRole = UserRole.elder;
            break;
          case 'caregiver':
            userRole = UserRole.caregiver;
            break;
          case 'therapist':
            userRole = UserRole.therapist;
            break;
          case 'doctor':
            userRole = UserRole.doctor;
            break;
          default:
            userRole = UserRole.elder;
        }

        final userService = UserService();
        final name = usernameController.text.trim().split('@')[0];

        await userService.saveUser(
          AppUser(
            uid: user.uid,
            elderId: user.uid,
            email: user.email ?? usernameController.text.trim(),
            role: userRole,
            name: name,
          ),
        );

        if (!mounted) return;

        if (userRole == UserRole.elder) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const SessionWrapper(child: ElderOnboardingFlow()),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const SessionWrapper(child: AuthWrapper()),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
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
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    const Color(0xFFE0F2F1),
                    const Color(0xFFB2EBF2).withOpacity(0.4),
                    const Color(0xFFE0F2F1),
                  ],
                ),
              ),
            ),
          ),

          // Abstract circles
          Positioned(
            top: -80,
            left: -40,
            child: _BlurredCircle(
              color: brownDark.withOpacity(0.1),
              size: 280,
            ),
          ),
          Positioned(
            bottom: 40,
            right: -60,
            child: _BlurredCircle(
              color: const Color(0xFF00BBA7).withOpacity(0.08),
              size: 260,
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
                                    _buildFields(brownDark),
                                    const SizedBox(height: 32),
                                    _buildSignUpButton(brownDark),
                                    const SizedBox(height: 24),
                                    _buildLoginLink(brownDark),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Bottom Icon
                          Opacity(
                            opacity: 0.3,
                            child: Icon(
                              Icons.volunteer_activism_rounded,
                              color: brownDark,
                              size: 44,
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.favorite_rounded, color: color, size: 36),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join Eldease today',
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
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
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

  Widget _buildFields(Color color) {
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: role,
          items: const [
            DropdownMenuItem(value: 'elder', child: Text('Elder')),
            DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
            DropdownMenuItem(value: 'therapist', child: Text('Therapist')),
            DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
          ],
          onChanged: loading ? null : (v) => setState(() => role = v!),
          decoration: InputDecoration(
            hintText: 'Select Role',
            prefixIcon: Icon(Icons.badge_outlined, size: 22, color: color.withOpacity(0.7)),
          ),
          dropdownColor: Colors.white,
          iconEnabledColor: color,
        ),
      ],
    );
  }

  Widget _buildSignUpButton(Color color) {
    return Hero(
      tag: 'auth_button',
      child: ElevatedButton(
        onPressed: loading ? null : _handleRegister,
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
            : const Text('Sign Up'),
      ),
    );
  }

  Widget _buildLoginLink(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.w500),
        ),
        GestureDetector(
          onTap: loading ? null : () => Navigator.pop(context),
          child: Text(
            'Log in',
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

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Auth & Session
import 'widgets/auth_wrapper.dart';
import 'widgets/session_wrapper.dart';

// Doctor dashboard route
import 'pages/doctor/doctor_dashboard_page.dart';

// Voice chatbot route
import 'features/voice_chatbot/screens/chat_screen.dart';

// App theme (use YOUR existing theme file path here)
import 'features/voice_chatbot/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eldercare App',

      // Global theme
      theme: AppTheme.lightTheme,

      // Default entry (auth flow)
      home: const SessionWrapper(child: AuthWrapper()),

      // Named routes (so you can navigate + sign out cleanly)
      routes: {
        // Auth entry page (Login/Register via your wrapper)
        '/auth': (_) => const SessionWrapper(child: AuthWrapper()),

        // Doctor dashboard
        '/doctor': (_) => const DoctorDashboardPage(),

        // Voice chatbot
        '/voice-chatbot': (_) => const ChatScreen(),
      },
    );
  }
}

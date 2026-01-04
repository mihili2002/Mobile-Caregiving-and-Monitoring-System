import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// Auth gate
import 'auth/auth_gate.dart';

// Auth & Session
import 'widgets/auth_wrapper.dart';
import 'widgets/session_wrapper.dart';

// Elder dashboard


// ✅ Voice chatbot feature imports
import 'features/voice_chatbot/screens/chat_screen.dart';
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

      // ✅ Using your chatbot theme for the whole app
      theme: AppTheme.lightTheme,

      // App starts with SessionWrapper + AuthWrapper
      home: const SessionWrapper(child: AuthWrapper()),

      // ✅ Add route to open your ChatScreen from anywhere
      routes: {
        '/voice-chatbot': (_) => const ChatScreen(),
      },
    );
  }
}

/* ------------------------------------------------------------------
   HOME PAGE (shown after successful login)
-------------------------------------------------------------------*/
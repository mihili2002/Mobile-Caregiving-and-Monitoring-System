import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Auth & Session
import 'widgets/auth_wrapper.dart';
import 'widgets/session_wrapper.dart';

// Doctor dashboard route
import 'pages/doctor/doctor_dashboard_page.dart';

// App theme
import 'features/voice_chatbot/theme/app_theme.dart';

import 'services/local_notification_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize local notifications (requests permissions inside service if you implemented it)
  await LocalNotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eldercare App',
      theme: AppTheme.lightTheme,

      // Entry point
      home: const SessionWrapper(child: AuthWrapper()),

      routes: {
        '/auth': (_) => const SessionWrapper(child: AuthWrapper()),
        '/doctor': (_) => const DoctorDashboardPage(),

        // ❌ REMOVE ChatScreen from routes
        // ChatScreen REQUIRES elderUid → must be opened via Navigator.push
      },
    );
  }
}

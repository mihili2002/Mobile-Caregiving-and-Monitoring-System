import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

// Auth gate
import 'auth/auth_gate.dart';

// Elder dashboard
import 'ElderDashboardScreen.dart';

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

      // App starts with AuthGate (keep this)
      home: const AuthGate(),

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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final role = user?.displayName ?? 'unknown';

    // ✅ ELDER → Elder Dashboard
    if (role.toLowerCase() == 'elder') {
      return const ElderDashboardScreen();
    }

    // ❌ Others → default home
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Logged in as: $role',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

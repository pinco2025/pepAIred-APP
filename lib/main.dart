import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prepaired/theme/app_theme.dart';
import 'package:prepaired/screens/auth_screen.dart';
import 'package:prepaired/screens/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace with your actual Supabase URL and Anon Key
  // Configure Supabase here. You can find these keys in your Supabase project settings.
  await Supabase.initialize(
    url: 'https://eznxtdzsvnfclgcavvhp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV6bnh0ZHpzdm5mY2xnY2F2dmhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2MDA5MDcsImV4cCI6MjA3ODE3NjkwN30.uxkZPGvN9-KXqulS-KguoFAvR33RluyNR-O3SNH8iwI',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prepaired',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // If the snapshot has data, use it to determine session status
        // Otherwise, fallback to checking currentSession directly
        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return const MainLayout();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'services/firestore_schema.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workouts/exercises_screen.dart';
import 'screens/workouts/ai_workout_screen.dart';
import 'screens/nutrition/nutrition_home_screen.dart';
import 'screens/nutrition/food_log_screen.dart';
import 'screens/ai/ai_chat_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Auto-seed starter templates locally if they are missing.
  await _maybeSeedTemplates();
  runApp(const MyApp());
}

Future<void> _maybeSeedTemplates() async {
  try {
    final db = FirebaseFirestore.instance;
    final templates = await db.collection('templates').limit(1).get();
    if (templates.docs.isEmpty) {
      // One-time seed using our helper.
      await FirestoreSeeder(db).seedTemplates();
    }
  } catch (_) {
    // Best-effort; ignore in release to avoid blocking app start.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'AI Fitness MVP',
        theme: AppTheme.light(),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/home': (_) => const HomeScreen(),
          '/exercises': (_) => const ExercisesScreen(),
          '/ai-workout': (_) => const AiWorkoutScreen(),
          '/nutrition': (_) => const NutritionHomeScreen(),
          '/food-log': (_) => const FoodLogScreen(),
          '/ai-chat': (_) => const AiChatScreen(),
          '/profile': (_) => const ProfileScreen(),
        },
      ),
    );
  }
}

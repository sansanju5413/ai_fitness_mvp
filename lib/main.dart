import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
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
  runApp(const MyApp());
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
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/firestore_schema.dart';
import '../services/local_data_service.dart';
import '../services/simple_ai_service.dart';
import '../services/gemini_ai_service.dart';
import '../models/exercise.dart';
import '../models/food_item.dart';

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final LocalDataService _localDataService = LocalDataService();
  final SimpleAiService _aiService = SimpleAiService();
  final GeminiAiService _geminiService = GeminiAiService(
    apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  );

  User? firebaseUser;
  AppUser? profile;

  List<Exercise> exercises = [];
  List<FoodItem> foods = [];
  List<Map<String, dynamic>> workoutTemplates = [];
  List<Map<String, dynamic>> nutritionTemplates = [];
  List<Map<String, dynamic>> habitTemplates = [];

  bool loading = false;

  AppState() {
    _authService.authStateChanges.listen((user) async {
      firebaseUser = user;
      if (user != null) {
        try {
          final existing = await _firestoreService.getUserProfile(user.uid);
          profile =
              existing ?? AppUser(uid: user.uid, email: user.email ?? '');
          await _loadTemplates();
        } catch (_) {
          profile = AppUser(uid: user.uid, email: user.email ?? '');
        }
      } else {
        profile = null;
      }
      notifyListeners();
    });
    _initLocalData();
  }

  Future<void> _initLocalData() async {
    exercises = await _localDataService.loadExercises();
    foods = await _localDataService.loadFoods();
    notifyListeners();
  }

  Future<void> _loadTemplates() async {
    workoutTemplates = await _firestoreService.getTemplates(
      type: FirestoreSchema.templateTypeWorkout,
    );
    nutritionTemplates = await _firestoreService.getTemplates(
      type: FirestoreSchema.templateTypeNutrition,
    );
    habitTemplates = await _firestoreService.getTemplates(
      type: FirestoreSchema.templateTypeHabit,
    );
    notifyListeners();
  }

  /// Admin-only: seed starter templates into Firestore, then reload locally.
  Future<void> seedTemplates() async {
    loading = true;
    notifyListeners();
    await _firestoreService.seedTemplates();
    await _loadTemplates();
    loading = false;
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    loading = true;
    notifyListeners();
    await _authService.signUp(email: email, password: password);
    loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    loading = true;
    notifyListeners();
    await _authService.signIn(email: email, password: password);
    loading = false;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    loading = true;
    notifyListeners();
    await _authService.signInWithGoogle();
    loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> updateProfile(AppUser updated) async {
    profile = updated;
    await _firestoreService.saveUserProfile(updated);
    notifyListeners();
  }

  Future<void> setActivePlans({
    String? workoutTemplate,
    String? nutritionTemplate,
    String? habitTemplate,
  }) async {
    if (profile == null) return;
    final updated = AppUser(
      uid: profile!.uid,
      email: profile!.email,
      name: profile!.name,
      age: profile!.age,
      gender: profile!.gender,
      heightCm: profile!.heightCm,
      weightKg: profile!.weightKg,
      goal: profile!.goal,
      activityLevel: profile!.activityLevel,
      activeWorkoutTemplate:
          workoutTemplate ?? profile!.activeWorkoutTemplate,
      activeNutritionTemplate:
          nutritionTemplate ?? profile!.activeNutritionTemplate,
      activeHabitTemplate: habitTemplate ?? profile!.activeHabitTemplate,
    );
    profile = updated;
    notifyListeners();
    await _firestoreService.setActiveTemplates(
      uid: profile!.uid,
      workoutTemplate: workoutTemplate,
      nutritionTemplate: nutritionTemplate,
      habitTemplate: habitTemplate,
    );
  }

  Future<void> logWorkout(Map<String, dynamic> session) async {
    if (firebaseUser == null) return;
    await _firestoreService.addWorkoutSession(firebaseUser!.uid, session);
  }

  Future<void> logFood(Map<String, dynamic> log) async {
    if (firebaseUser == null) return;
    await _firestoreService.addFoodLog(firebaseUser!.uid, log);
  }

  SimpleAiService get ai => _aiService;

  bool get hasGemini => _geminiService.isConfigured;

  Future<String> askAi(String question) async {
    if (_geminiService.isConfigured) {
      return _geminiService.chat(question);
    }
    return _aiService.answerQuestion(question);
  }

  Future<Map<String, List<String>>> generateWorkoutPlanAi({
    required String goal,
    required int daysPerWeek,
  }) async {
    if (_geminiService.isConfigured) {
      final summary = _buildProfileSummary();
      return _geminiService.generateWorkoutPlan(
        goal: goal,
        daysPerWeek: daysPerWeek,
        templateName: profile?.activeWorkoutTemplate,
        profileSummary: summary,
      );
    }
    return _aiService.generateWorkoutPlan(
      goal: goal,
      daysPerWeek: daysPerWeek,
    );
  }

  String? _buildProfileSummary() {
    if (profile == null) return null;
    final parts = <String>[];
    if (profile!.age != null) parts.add('age ${profile!.age}');
    if (profile!.gender != null) parts.add('gender ${profile!.gender}');
    if (profile!.heightCm != null) {
      parts.add('height ${profile!.heightCm!.toStringAsFixed(0)}cm');
    }
    if (profile!.weightKg != null) {
      parts.add('weight ${profile!.weightKg!.toStringAsFixed(0)}kg');
    }
    if (profile!.activityLevel != null) {
      parts.add('activity ${profile!.activityLevel}');
    }
    if (profile!.goal != null) {
      parts.add('goal ${profile!.goal}');
    }
    if (profile!.activeWorkoutTemplate != null) {
      parts.add('using template ${profile!.activeWorkoutTemplate}');
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}
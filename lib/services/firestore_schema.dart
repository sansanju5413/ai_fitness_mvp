import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralizes collection/field names and provides starter template seeding.
class FirestoreSchema {
  /// Top-level collections.
  static const users = 'users';
  static const templates = 'templates';

  /// Sub-collections under `users/{uid}`.
  static const userWorkouts = 'workoutSessions';
  static const userFoodLogs = 'foodLogs';
  static const userHabits = 'habitLogs';
  static const userMetrics = 'metrics';

  /// Template document types.
  static const templateTypeWorkout = 'workout';
  static const templateTypeNutrition = 'nutrition';
  static const templateTypeHabit = 'habit';
}

/// Provides a minimal set of default templates to make the app usable out of the box.
class FirestoreSeeder {
  FirestoreSeeder(this._db);

  final FirebaseFirestore _db;

  /// Seed starter templates (idempotent).
  Future<void> seedTemplates() async {
    final batch = _db.batch();

    final workoutTemplates = [
      {
        'type': FirestoreSchema.templateTypeWorkout,
        'name': 'Beginner full body',
        'daysPerWeek': 3,
        'description': 'Foundational strength, 45m, minimal equipment',
        'blocks': [
          {
            'day': 'Day 1',
            'exercises': ['Squat', 'Push-up', 'Row', 'Plank'],
          },
          {
            'day': 'Day 2',
            'exercises': ['Hinge', 'Press', 'Carry', 'Core'],
          },
          {
            'day': 'Day 3',
            'exercises': ['Split squat', 'Pull', 'Push', 'Anti-rotation'],
          },
        ],
      },
      {
        'type': FirestoreSchema.templateTypeWorkout,
        'name': 'Upper/Lower split',
        'daysPerWeek': 4,
        'description': 'Hypertrophy focus, dumbbells or gym',
      },
      {
        'type': FirestoreSchema.templateTypeWorkout,
        'name': 'Push/Pull/Legs',
        'daysPerWeek': 5,
        'description': 'Intermediate volume, gym preferred',
      },
    ];

    final nutritionTemplates = [
      {
        'type': FirestoreSchema.templateTypeNutrition,
        'name': 'Cut 1800 kcal',
        'calories': 1800,
        'macros': {'protein': 160, 'carbs': 150, 'fats': 55},
      },
      {
        'type': FirestoreSchema.templateTypeNutrition,
        'name': 'Maintenance 2100 kcal',
        'calories': 2100,
        'macros': {'protein': 150, 'carbs': 210, 'fats': 65},
      },
      {
        'type': FirestoreSchema.templateTypeNutrition,
        'name': 'Bulk 2500 kcal',
        'calories': 2500,
        'macros': {'protein': 170, 'carbs': 260, 'fats': 75},
      },
    ];

    final habitTemplates = [
      {
        'type': FirestoreSchema.templateTypeHabit,
        'name': 'Hydration',
        'targetPerDay': 8,
        'unit': 'glasses',
      },
      {
        'type': FirestoreSchema.templateTypeHabit,
        'name': 'Sleep',
        'targetPerDay': 8,
        'unit': 'hours',
      },
      {
        'type': FirestoreSchema.templateTypeHabit,
        'name': 'Mobility',
        'targetPerDay': 10,
        'unit': 'minutes',
      },
    ];

    void addTemplates(List<Map<String, dynamic>> items) {
      for (final item in items) {
        final docRef =
            _db.collection(FirestoreSchema.templates).doc(item['name'] as String);
        batch.set(docRef, item, SetOptions(merge: true));
      }
    }

    addTemplates(workoutTemplates);
    addTemplates(nutritionTemplates);
    addTemplates(habitTemplates);

    await batch.commit();
  }
}


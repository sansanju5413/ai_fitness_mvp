import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'firestore_schema.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -------- Users --------
  Future<void> saveUserProfile(AppUser user) async {
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw Exception('Failed to save profile: ${e.message}');
    }
  }

  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return AppUser.fromMap(data);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  // -------- Templates --------
  Future<List<Map<String, dynamic>>> getTemplates({String? type}) async {
    Query<Map<String, dynamic>> query =
        _db.collection(FirestoreSchema.templates);
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    final snap = await query.get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // -------- User selections --------
  Future<void> setActiveTemplates({
    required String uid,
    String? workoutTemplate,
    String? nutritionTemplate,
    String? habitTemplate,
  }) async {
    final updates = <String, dynamic>{};
    if (workoutTemplate != null) {
      updates['activeWorkoutTemplate'] = workoutTemplate;
    }
    if (nutritionTemplate != null) {
      updates['activeNutritionTemplate'] = nutritionTemplate;
    }
    if (habitTemplate != null) {
      updates['activeHabitTemplate'] = habitTemplate;
    }
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).set(updates, SetOptions(merge: true));
  }

  // -------- Logs --------
  Future<void> addWorkoutSession(String uid, Map<String, dynamic> session) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('workoutSessions')
          .add(session);
    } on FirebaseException catch (e) {
      throw Exception('Failed to add workout session: ${e.message}');
    }
  }

  Future<void> addFoodLog(String uid, Map<String, dynamic> log) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('foodLogs')
          .add(log);
    } on FirebaseException catch (e) {
      throw Exception('Failed to add food log: ${e.message}');
    }
  }

  Future<void> addHabitLog(String uid, Map<String, dynamic> log) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('habitLogs')
          .add(log);
    } on FirebaseException catch (e) {
      throw Exception('Failed to add habit log: ${e.message}');
    }
  }

  Future<void> addMetric(String uid, Map<String, dynamic> metric) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('metrics')
          .add(metric);
    } on FirebaseException catch (e) {
      throw Exception('Failed to add metric: ${e.message}');
    }
  }

  // -------- Seeding (admin-only, call once) --------
  Future<void> seedTemplates() async {
    final seeder = FirestoreSeeder(_db);
    await seeder.seedTemplates();
  }
}
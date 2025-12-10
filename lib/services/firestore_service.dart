import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
}
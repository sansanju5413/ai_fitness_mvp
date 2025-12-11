class AppUser {
  final String uid;
  final String email;
  final String? name;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? goal; // fat_loss, muscle_gain, general
  final String? activityLevel; // sedentary, moderate, active
  final String? activeWorkoutTemplate;
  final String? activeNutritionTemplate;
  final String? activeHabitTemplate;

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.activityLevel,
    this.activeWorkoutTemplate,
    this.activeNutritionTemplate,
    this.activeHabitTemplate,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'goal': goal,
      'activityLevel': activityLevel,
      'activeWorkoutTemplate': activeWorkoutTemplate,
      'activeNutritionTemplate': activeNutritionTemplate,
      'activeHabitTemplate': activeHabitTemplate,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      name: map['name'] as String?,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      goal: map['goal'] as String?,
      activityLevel: map['activityLevel'] as String?,
      activeWorkoutTemplate: map['activeWorkoutTemplate'] as String?,
      activeNutritionTemplate: map['activeNutritionTemplate'] as String?,
      activeHabitTemplate: map['activeHabitTemplate'] as String?,
    );
  }
}

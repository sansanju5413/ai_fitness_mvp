import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/exercise.dart';
import '../models/food_item.dart';

class LocalDataService {
  Future<List<Exercise>> loadExercises() async {
    final raw = await rootBundle.loadString('assets/data/exercises.json');
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FoodItem>> loadFoods() async {
    final raw = await rootBundle.loadString('assets/data/foods.json');
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
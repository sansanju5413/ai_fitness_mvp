import '../models/food_item.dart';

class SimpleAiService {
  /// Very simple AI-like workout generator based on goal & days per week.
  Map<String, List<String>> generateWorkoutPlan({
    required String goal, // fat_loss, muscle_gain, general
    required int daysPerWeek,
  }) {
    final Map<String, List<String>> plan = {};
    for (int day = 1; day <= daysPerWeek; day++) {
      if (goal == 'fat_loss') {
        plan['Day $day'] = [
          'Warm up 5 min brisk walk',
          'Bodyweight Squats 3x15',
          'Push-Ups 3x10',
          'Plank 3x30s',
          'Cool down 5 min stretching',
        ];
      } else if (goal == 'muscle_gain') {
        plan['Day $day'] = [
          'Push-Ups 4x10-12',
          'Bodyweight Squats 4x12',
          'Lunges 3x12 each leg',
          'Glute Bridges 3x15',
        ];
      } else {
        plan['Day $day'] = [
          'Walk 20 min',
          'Push-Ups 2x10',
          'Bodyweight Squats 2x15',
          'Plank 2x20s',
        ];
      }
    }
    return plan;
  }

  /// Simple text-based answer generator for demo purposes.
  String answerQuestion(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('fat') && lower.contains('lose')) {
      return 'To lose fat, focus on a small calorie deficit, 3-4 days of full body workouts, and daily walking. Start with 20-30 minutes of brisk walking and 3 sets of squats, push-ups, and planks.';
    }
    if (lower.contains('muscle')) {
      return 'For muscle gain, train 3-5 days per week with progressive overload. Use 3-4 sets of 8-12 reps for big exercises like squats, push-ups, rows, and overhead presses, and eat sufficient protein.';
    }
    return 'Aim for a mix of strength training 3-4 days per week, daily light movement (like walking), and balanced meals with enough protein, complex carbs, and healthy fats.';
  }

  /// Simple meal plan based on calorie goal.
  List<String> generateMealPlan(double targetCalories, List<FoodItem> foods) {
    final List<String> meals = [];
    final rice = foods.firstWhere((f) => f.id == 'rice', orElse: () => foods.first);
    final egg = foods.firstWhere((f) => f.id == 'egg', orElse: () => foods.first);
    final banana = foods.firstWhere((f) => f.id == 'banana', orElse: () => foods.first);
    final milk = foods.firstWhere((f) => f.id == 'milk', orElse: () => foods.first);

    if (targetCalories <= 1600) {
      meals.add('Breakfast: ${milk.servingSize.toInt()}${milk.unit} ${milk.name} + 1 ${banana.name}');
      meals.add('Lunch: 1 plate ${rice.name} + 2 ${egg.name}s + vegetables');
      meals.add('Snack: 1 ${banana.name}');
      meals.add('Dinner: 1 plate ${rice.name} + 1 ${egg.name} + salad');
    } else if (targetCalories <= 2200) {
      meals.add('Breakfast: ${milk.servingSize.toInt()}${milk.unit} ${milk.name} + 2 ${egg.name}s');
      meals.add('Lunch: 1.5 plate ${rice.name} + 2 ${egg.name}s + vegetables');
      meals.add('Snack: 1 ${banana.name} + handful nuts');
      meals.add('Dinner: 1 plate ${rice.name} + 2 ${egg.name}s + salad');
    } else {
      meals.add('Breakfast: ${milk.servingSize.toInt()}${milk.unit} ${milk.name} + 2 ${egg.name}s + 1 ${banana.name}');
      meals.add('Lunch: 2 plate ${rice.name} + 2-3 ${egg.name}s + vegetables');
      meals.add('Snack: 1 ${banana.name} + nuts + milk');
      meals.add('Dinner: 1.5 plate ${rice.name} + 2 ${egg.name}s + salad');
    }

    return meals;
  }
}
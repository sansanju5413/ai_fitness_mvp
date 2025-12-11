import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_item.dart';

import '../../providers/app_state.dart';
import '../../services/simple_ai_service.dart';
import '../../widgets/fitness_page.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({super.key});

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _macroController;
  late final AnimationController _timelineController;
  late final PageController _insightsController;
  Timer? _insightsTimer;
  int _hydration = 5;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _macroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _timelineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _insightsController = PageController(viewportFraction: 0.88);
    _insightsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_insightsController.hasClients) return;
      final next = (_insightsController.page ?? 0).round() + 1;
      final page = next % _insights.length;
      _insightsController.animateToPage(
        page,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _insightsTimer?.cancel();
    _ringController.dispose();
    _macroController.dispose();
    _timelineController.dispose();
    _insightsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final foods = appState.foods;
    final ai = appState.ai;
    final goal = appState.profile?.goal ?? 'general';

    final targets = _targetsForGoal(goal);
    final consumed = _mockTodayMacros(foods);
    final remaining =
        (targets.calories - consumed.calories).clamp(0, 5000).toDouble();

    final selectedTemplate = appState.profile?.activeNutritionTemplate;
    final mealPlan = _selectedMealPlan(
      selectedTemplate,
      foods,
      ai,
      targets.calories,
    );

    return FitnessPage(
      appBar: AppBar(
        title: const Text('Nutrition'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {});
              _ringController.forward(from: 0);
              _macroController.forward(from: 0);
              _timelineController.forward(from: 0);
            },
          ),
        ],
      ),
      scrollable: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    final aspect = isNarrow ? (4 / 3) : (16 / 9);
                    return AspectRatio(
                      aspectRatio: aspect,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/Schwinn_IC3_Indoor_Cycling_Bike_Review.jpg',
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.55),
                                  Colors.black.withOpacity(0.35),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Fuel your training',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stay on target with clear macros and hydration.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              _CalorieRing(
                animation: _ringController,
                consumed: consumed.calories,
                target: targets.calories,
                remaining: remaining,
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 420;
                  if (isNarrow) {
                    return Column(
                      children: [
                        _MacroRow(
                          animation: _macroController,
                          consumed: consumed,
                          targets: targets,
                        ),
                      ],
                    );
                  }
                  return _MacroRow(
                    animation: _macroController,
                    consumed: consumed,
                    targets: targets,
                  );
                },
              ),
              const SizedBox(height: 16),
              _QuickActions(onTap: _onQuickAction),
              const SizedBox(height: 16),
              _MealTimeline(
                animation: _timelineController,
                meals: _buildMeals(consumed),
                onAdd: (slot) => _showSnack('Add to ${slot.name}'),
              ),
              const SizedBox(height: 16),
              _HydrationBottle(
                count: _hydration,
                target: 8,
                onAdd: () {
                  setState(() => _hydration = math.min(8, _hydration + 1));
                  _showSnack('Nice! ${_hydration}/8 glasses');
                },
              ),
              const SizedBox(height: 16),
              _Insights(
                controller: _insightsController,
                items: _insights,
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Today\'s meals',
                subtitle: 'Tap a meal to see details',
              ),
              const SizedBox(height: 8),
              _MealPlanList(mealPlan: mealPlan),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Log today\'s food'),
                  onPressed: () => Navigator.pushNamed(context, '/food-log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onQuickAction(String action) {
    _showSnack('$action coming soon');
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _MacroTargets {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  const _MacroTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

class _MacroProgress {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  const _MacroProgress({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

_MacroTargets _targetsForGoal(String goal) {
  if (goal == 'fat_loss') {
    return const _MacroTargets(
      calories: 1600,
      protein: 140,
      carbs: 140,
      fats: 55,
    );
  }
  if (goal == 'muscle_gain') {
    return const _MacroTargets(
      calories: 2300,
      protein: 170,
      carbs: 240,
      fats: 70,
    );
  }
  return const _MacroTargets(
    calories: 2000,
    protein: 150,
    carbs: 200,
    fats: 60,
  );
}

_MacroProgress _mockTodayMacros(List<FoodItem> foods) {
  if (foods.isEmpty) {
    return const _MacroProgress(
      calories: 980,
      protein: 82,
      carbs: 110,
      fats: 35,
    );
  }
  final first = foods.first;
  return _MacroProgress(
    calories: (first.calories * 3).clamp(600, 2200),
    protein: (first.protein * 3).clamp(60, 180),
    carbs: (first.carbs * 3).clamp(80, 240),
    fats: (first.fat * 3).clamp(30, 90),
  );
}

List<_MealSlot> _buildMeals(_MacroProgress macros) {
  return [
    _MealSlot(
      name: 'Breakfast',
      time: '8:00 AM',
      calories: (macros.calories * 0.22).round(),
      logged: true,
    ),
    _MealSlot(
      name: 'Lunch',
      time: '12:45 PM',
      calories: (macros.calories * 0.28).round(),
      logged: true,
    ),
    _MealSlot(
      name: 'Snacks',
      time: '4:00 PM',
      calories: (macros.calories * 0.12).round(),
      logged: false,
    ),
    _MealSlot(
      name: 'Dinner',
      time: '8:00 PM',
      calories: (macros.calories * 0.26).round(),
      logged: false,
    ),
    _MealSlot(
      name: 'Post-Workout',
      time: '9:30 PM',
      calories: (macros.calories * 0.12).round(),
      logged: false,
    ),
  ];
}

List<String> _selectedMealPlan(
  String? template,
  List<FoodItem> foods,
  SimpleAiService ai,
  double target,
) {
  if (template != null && _nutritionTemplates.containsKey(template)) {
    return _nutritionTemplates[template]!;
  }
  if (foods.isEmpty) return const [];
  return ai.generateMealPlan(target, foods);
}

class _CalorieRing extends StatelessWidget {
  final Animation<double> animation;
  final double consumed;
  final double target;
  final double remaining;

  const _CalorieRing({
    required this.animation,
    required this.consumed,
    required this.target,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (consumed / target).clamp(0.0, 1.2);
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: CustomPaint(
              painter: _RingPainter(
                progress: ratio,
              ),
              child: Center(
                child: Text(
                  '${consumed.toInt()} kcal',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily overview',
                  style: textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                _StatRow(label: 'Target', value: '${target.toInt()} kcal'),
                const SizedBox(height: 4),
                _StatRow(label: 'Remaining', value: '${remaining.toInt()} kcal'),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  value: null,
                  backgroundColor: Colors.white12,
                  color: Colors.white24,
                  minHeight: 4,
                ),
                const SizedBox(height: 8),
                Text(
                  'Stay within target by adding protein-rich foods.',
                  style:
                      textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final Animation<double> animation;
  final _MacroProgress consumed;
  final _MacroTargets targets;

  const _MacroRow({
    required this.animation,
    required this.consumed,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MacroCard(
        title: 'Protein',
        consumed: consumed.protein,
        target: targets.protein,
        color: Colors.blueAccent,
        icon: Icons.set_meal_rounded,
      ),
      _MacroCard(
        title: 'Carbs',
        consumed: consumed.carbs,
        target: targets.carbs,
        color: Colors.orangeAccent,
        icon: Icons.rice_bowl_outlined,
      ),
      _MacroCard(
        title: 'Fats',
        consumed: consumed.fats,
        target: targets.fats,
        color: Colors.amber,
        icon: Icons.breakfast_dining_rounded,
      ),
    ];
    return Row(
      children: cards
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key == cards.length - 1 ? 0 : 8,
                ),
                child: entry.value,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String title;
  final double consumed;
  final double target;
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.title,
    required this.consumed,
    required this.target,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (consumed / target).clamp(0.0, 1.2);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${consumed.toStringAsFixed(0)}g / ${target.toStringAsFixed(0)}g',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 800),
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white10,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final void Function(String) onTap;

  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Scan Barcode', Icons.qr_code_scanner),
      ('Voice Add', Icons.mic_none_rounded),
      ('Recent Foods', Icons.history_rounded),
      ('Favorites', Icons.star_border_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final size = isNarrow ? 52.0 : 60.0;
        final spacing = isNarrow ? 8.0 : 12.0;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.spaceBetween,
          children: items
              .map(
                (item) => _QuickActionButton(
                  label: item.$1,
                  icon: item.$2,
                  onTap: () => onTap(item.$1),
                  size: size,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double? size;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        children: [
          Container(
            height: size ?? 60,
            width: size ?? 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MealTimeline extends StatelessWidget {
  final Animation<double> animation;
  final List<_MealSlot> meals;
  final void Function(_MealSlot) onAdd;

  const _MealTimeline({
    required this.animation,
    required this.meals,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Meal timeline',
            subtitle: 'Tap to add items to a meal',
          ),
          const SizedBox(height: 10),
          Column(
            children: meals
                .asMap()
                .entries
                .map(
                  (entry) => _MealTile(
                    slot: entry.value,
                    isActive: _isCurrentMeal(now, entry.value),
                    isLast: entry.key == meals.length - 1,
                    onAdd: () => onAdd(entry.value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

bool _isCurrentMeal(TimeOfDay now, _MealSlot slot) {
  final parts = slot.time.split(' ');
  final hm = parts.first.split(':');
  var hour = int.parse(hm.first);
  final minute = int.parse(hm.last);
  if (parts.last.toUpperCase() == 'PM' && hour != 12) {
    hour += 12;
  }
  if (parts.last.toUpperCase() == 'AM' && hour == 12) {
    hour = 0;
  }
  return now.hour == hour ? now.minute >= minute - 30 : now.hour == hour - 1;
}

class _MealTile extends StatelessWidget {
  final _MealSlot slot;
  final bool isActive;
  final bool isLast;
  final VoidCallback onAdd;

  const _MealTile({
    required this.slot,
    required this.isActive,
    required this.isLast,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isActive ? Colors.greenAccent : Colors.white70;
    return Stack(
      children: [
        Positioned(
          top: 18,
          left: 14,
          right: 14,
          child: CustomPaint(
            painter: _DottedLinePainter(color: Colors.white24),
            size: Size.fromHeight(isLast ? 0 : 62),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  height: 18,
                  width: 18,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast) const SizedBox(height: 70),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(isActive ? 0.15 : 0.08),
                  border: Border.all(
                    color: isActive
                        ? Colors.greenAccent.withOpacity(0.7)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        Text(
                          slot.time,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white60),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${slot.calories} kcal',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: onAdd,
                      icon: Icon(
                        slot.logged ? Icons.check_rounded : Icons.add,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            slot.logged ? Colors.greenAccent : Colors.white24,
                        minimumSize: const Size(42, 42),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HydrationBottle extends StatelessWidget {
  final int count;
  final int target;
  final VoidCallback onAdd;

  const _HydrationBottle({
    required this.count,
    required this.target,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final fill = (count / target).clamp(0.0, 1.0);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAdd,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 70,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                Container(
                  width: 70,
                  height: 140 * fill,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF7dd3fc), Color(0xFF0ea5e9)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hydration',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '$count/$target glasses today',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(
                    target,
                    (i) => Icon(
                      i < count
                          ? Icons.local_drink_rounded
                          : Icons.local_drink_outlined,
                      color: i < count ? Colors.lightBlueAccent : Colors.white38,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final PageController controller;
  final List<_InsightCard> items;

  const _Insights({
    required this.controller,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: PageView.builder(
        controller: controller,
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _MealPlanList extends StatelessWidget {
  final List<String> mealPlan;

  const _MealPlanList({required this.mealPlan});

  @override
  Widget build(BuildContext context) {
    if (mealPlan.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No meal suggestions yet.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mealPlan.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.08),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mealPlan[index],
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.greenAccent, Color(0xFF10b981)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, bgPaint);
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashWidth = 4;
    const dashSpace = 6;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MealSlot {
  final String name;
  final String time;
  final int calories;
  final bool logged;

  _MealSlot({
    required this.name,
    required this.time,
    required this.calories,
    required this.logged,
  });
}

const _insights = <_InsightCard>[
  _InsightCard(
    title: 'You\'re 200 cal below target',
    subtitle: 'Add a protein snack to hit your goal.',
    icon: Icons.speed_rounded,
    color: Colors.orangeAccent,
  ),
  _InsightCard(
    title: 'Great protein intake!',
    subtitle: 'Keep up the lean protein choices.',
    icon: Icons.check_circle_rounded,
    color: Colors.greenAccent,
  ),
  _InsightCard(
    title: 'Consider adding vegetables',
    subtitle: 'Aim for 2 more servings today.',
    icon: Icons.eco_rounded,
    color: Colors.lightGreenAccent,
  ),
  _InsightCard(
    title: 'Your best week yet!',
    subtitle: '5 days logged in a row.',
    icon: Icons.emoji_events_rounded,
    color: Colors.amberAccent,
  ),
];

const Map<String, List<String>> _nutritionTemplates = {
  'Lean cut (low fat, high protein)': [
    'Breakfast: Greek yogurt bowl with berries + oats',
    'Lunch: Grilled chicken, quinoa, roasted veggies',
    'Snack: Protein shake + banana',
  ],
  'Maintenance balance': [
    'Breakfast: Scrambled eggs + toast + avocado',
    'Lunch: Rice bowl with tofu, veggies, sesame',
    'Snack: Cottage cheese + fruit',
    'Dinner: Lean beef stir-fry with rice noodles',
  ],
  'Muscle gain': [
    'Breakfast: Oats, whey, banana, peanut butter',
    'Lunch: Chicken burrito bowl with beans + rice',
    'Snack: Yogurt + granola + berries',
    'Dinner: Pasta with turkey mince + veggies',
  ],
};

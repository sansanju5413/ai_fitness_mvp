
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fitness_page.dart';
import 'ai/ai_chat_screen.dart';
import 'nutrition/food_log_screen.dart';
import 'nutrition/nutrition_home_screen.dart';
import 'profile_screen.dart';
import 'workouts/ai_workout_screen.dart';
import 'workouts/exercises_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;

    final List<Widget> pages = [
      _HomeDashboard(
        profileName: profile?.name ?? 'Athlete',
        workoutTemplate: profile?.activeWorkoutTemplate,
        nutritionTemplate: profile?.activeNutritionTemplate,
      ),
      const ExercisesScreen(),
      const NutritionHomeScreen(),
      const AiChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            label: 'Nutrition',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            label: 'AI Coach',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboard extends StatefulWidget {
  final String profileName;
  final String? workoutTemplate;
  final String? nutritionTemplate;

  const _HomeDashboard({
    required this.profileName,
    this.workoutTemplate,
    this.nutritionTemplate,
  });

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _heroFade;

  late final AnimationController _staggerController;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;
  bool _isOffline = false;

  double _workoutCompletion = 0.72;
  double _nutritionCompletion = 0.56;
  double _recoveryScore = 0.64;

  final List<_Habit> _habits = [
    _Habit(
      id: 'breathing',
      title: 'Breathing reset',
      subtitle: '4-7-8 box breathing – 3 min',
      progress: 0.4,
    ),
    _Habit(
      id: 'mobility',
      title: 'Mobility flow',
      subtitle: 'Hip + T-spine – 8 min',
      progress: 0.6,
    ),
    _Habit(
      id: 'sleep',
      title: 'Sleep wind-down',
      subtitle: 'Screens off – 30 min',
      progress: 0.3,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeOutCubic,
      ),
    );
    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _loadData();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _heroController.forward();
      _staggerController.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true;
      _hasError = false;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _workoutCompletion =
            (_workoutCompletion + 0.08).clamp(0.0, 1.0);
        _nutritionCompletion =
            (_nutritionCompletion + 0.06).clamp(0.0, 1.0);
        _recoveryScore = (_recoveryScore + 0.05).clamp(0.0, 1.0);
        _isOffline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isOffline = true;
      });
      _showErrorSnackBar(
        context,
        message: 'Unable to refresh. You might be offline.',
        onRetry: _onRefresh,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _safeAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar(
        context,
        message: 'Something went wrong. Please try again.',
        onRetry: () => _safeAction(action),
      );
    }
  }

  void _onToggleHabit(String id) {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return;
    setState(() {
      final habit = _habits[index];
      habit.isCompleted = !habit.isCompleted;
      habit.progress = habit.isCompleted ? 1 : habit.progress;
    });
  }

  void _onReorderHabit(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _habits.removeAt(oldIndex);
      _habits.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isSmall = width < 360;
        final isNarrow = width < 600;
        final padding = EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: 12,
        );

        final content = RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface.withOpacity(0.95),
          strokeWidth: 2.4,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        const _HeroSkeleton()
                      else
                        RepaintBoundary(
                          child: _HeroSection(
                            profileName: widget.profileName,
                            slide: _heroSlide,
                            fade: _heroFade,
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (widget.workoutTemplate != null ||
                          widget.nutritionTemplate != null)
                        RepaintBoundary(
                          child: _TemplatePlanCard(
                            workoutTemplate: widget.workoutTemplate,
                            nutritionTemplate: widget.nutritionTemplate,
                          ),
                        ),
                      if (widget.workoutTemplate != null ||
                          widget.nutritionTemplate != null)
                        const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SectionHeader(
                              title: 'Today\'s snapshot',
                              subtitle:
                                  'Keep momentum with quick actions',
                            ),
                          ),
                          if (_isOffline)
                            const _OfflineBadge(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        child: _isLoading
                            ? const _ProgressRingSkeleton()
                            : _TodayProgressRing(
                                workout: _workoutCompletion,
                                nutrition: _nutritionCompletion,
                                recovery: _recoveryScore,
                              ),
                      ),
                      const SizedBox(height: 16),
                      RepaintBoundary(
                        child: _QuickActionsSection(
                          controller: _staggerController,
                          isNarrow: isNarrow,
                          hasError: _hasError,
                          isLoading: _isLoading,
                          onWorkout: () => _safeAction(() async {
                            await Navigator.of(context).push(
                              _slideRightRoute(const AiWorkoutScreen()),
                            );
                          }),
                          onNutrition: () => _safeAction(() async {
                            await Navigator.of(context).push(
                              _slideRightRoute(const FoodLogScreen()),
                            );
                          }),
                          onAi: () => _safeAction(() async {
                            await Navigator.of(context).push(
                              _slideRightRoute(const AiChatScreen()),
                            );
                          }),
                          onExercises: () => _safeAction(() async {
                            await Navigator.of(context).push(
                              _slideRightRoute(const ExercisesScreen()),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SectionHeader(
                              title: 'Recovery & habits',
                              subtitle:
                                  'Balance training with mobility and sleep',
                            ),
                          ),
                          const _BellReminderIcon(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        child: _RecoveryHabitsCard(
                          habits: _habits,
                          isLoading: _isLoading,
                          onToggle: _onToggleHabit,
                          onReorder: _onReorderHabit,
                        ),
                      ),
                      if (_hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Error: ',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'Some data may be out of date. Pull to refresh.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color:
                                        Colors.redAccent.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isRefreshing)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        return FitnessPage(
          appBar: AppBar(
            title: Text(
              'Hey ${widget.profileName}',
              style: textTheme.titleLarge,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () {
                  _safeAction(() async {
                    await Navigator.of(context).push(
                      _slideRightRoute(const ProfileScreen()),
                    );
                  });
                },
                icon: const Icon(Icons.person_outline, color: Colors.white),
              ),
            ],
          ),
          scrollable: false,
          child: content,
        );
      },
    );
  }
}

class _HeroSection extends StatefulWidget {
  final String profileName;
  final Animation<Offset> slide;
  final Animation<double> fade;

  const _HeroSection({
    required this.profileName,
    required this.slide,
    required this.fade,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: -0.08,
      upperBound: 0.08,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          const Positioned.fill(child: _HeroParticlesOverlay()),
          _Shimmer(
            child: Row(
              children: [
                Expanded(
                  child: SlideTransition(
                    position: widget.slide,
                    child: FadeTransition(
                      opacity: widget.fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your daily flow',
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Warm-up • Strength • Fuel • Recover',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _TagChip(label: 'AI Coach'),
                              _TagChip(label: 'Dynamic plan'),
                              _TagChip(label: 'Recovery tips'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Let\'s move, ${widget.profileName}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapDown: (_) => _iconController.forward(),
                  onTapUp: (_) => _iconController.reverse(),
                  onTapCancel: () => _iconController.reverse(),
                  child: AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconController.value,
                        child: child,
                      );
                    },
                    child: Container(
                      height: 92,
                      width: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.heroGradient(),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: Colors.white,
                        size: 42,
                      ),
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

class _HeroParticlesOverlay extends StatefulWidget {
  const _HeroParticlesOverlay();

  @override
  State<_HeroParticlesOverlay> createState() => _HeroParticlesOverlayState();
}

class _HeroParticlesOverlayState extends State<_HeroParticlesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlesPainter(progress: _controller.value),
          );
        },
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;

  _ParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final center = size.center(Offset.zero);
    final baseRadius = math.min(size.width, size.height) * 0.55;

    for (int i = 0; i < 16; i++) {
      final angle = 2 * math.pi * i / 16 + progress * 2 * math.pi;
      final r = baseRadius * (0.3 + (i % 5) * 0.1);
      final dx = center.dx + r * math.cos(angle);
      final dy = center.dy + r * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = rect.width * (_controller.value * 2 - 1);
            return const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white54,
                Colors.transparent,
              ],
              stops: [0.2, 0.5, 0.8],
            ).createShader(rect.shift(Offset(dx, 0)));
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _TodayProgressRing extends StatelessWidget {
  final double workout;
  final double nutrition;
  final double recovery;

  const _TodayProgressRing({
    required this.workout,
    required this.nutrition,
    required this.recovery,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Column(
          children: [
            SizedBox(
              height: 160,
              width: 160,
              child: CustomPaint(
                painter: _RingChartPainter(
                  workout: workout * t,
                  nutrition: nutrition * t,
                  recovery: recovery * t,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Today\'s progress',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(workout * 100).round()}%',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendDot(
                  color: Colors.greenAccent,
                  label: 'Workout',
                  value: workout,
                ),
                _LegendDot(
                  color: AppTheme.secondary,
                  label: 'Nutrition',
                  value: nutrition,
                ),
                _LegendDot(
                  color: Colors.amberAccent,
                  label: 'Recovery',
                  value: recovery,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RingChartPainter extends CustomPainter {
  final double workout;
  final double nutrition;
  final double recovery;

  _RingChartPainter({
    required this.workout,
    required this.nutrition,
    required this.recovery,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;

    final basePaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, basePaint);

    final total = workout + nutrition + recovery + 0.001;
    var start = -math.pi / 2;

    void draw(double value, Color color) {
      final sweep = (value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    draw(workout, Colors.greenAccent);
    draw(nutrition, AppTheme.secondary);
    draw(recovery, Colors.amberAccent);
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return oldDelegate.workout != workout ||
        oldDelegate.nutrition != nutrition ||
        oldDelegate.recovery != recovery;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(color: Colors.white70),
            ),
            Text(
              '${(value * 100).round()}%',
              style: textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final AnimationController controller;
  final bool isNarrow;
  final bool hasError;
  final bool isLoading;
  final VoidCallback onWorkout;
  final VoidCallback onNutrition;
  final VoidCallback onAi;
  final VoidCallback onExercises;

  const _QuickActionsSection({
    required this.controller,
    required this.isNarrow,
    required this.hasError,
    required this.isLoading,
    required this.onWorkout,
    required this.onNutrition,
    required this.onAi,
    required this.onExercises,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        children: [
          _SkeletonBox(height: 76),
          SizedBox(height: 8),
          _SkeletonBox(height: 76),
          SizedBox(height: 8),
          _SkeletonBox(height: 76),
          SizedBox(height: 8),
          _SkeletonBox(height: 76),
        ],
      );
    }

    final cards = [
      _QuickActionCard(
        label: 'Workout',
        description: 'Full body · 35m',
        icon: Icons.fitness_center,
        color: AppTheme.primary,
        completion: 0.72,
        isActive: true,
        index: 0,
        controller: controller,
        onTap: onWorkout,
      ),
      _QuickActionCard(
        label: 'Nutrition',
        description: 'Log meals & water',
        icon: Icons.restaurant_outlined,
        color: AppTheme.secondary,
        completion: 0.56,
        index: 1,
        controller: controller,
        onTap: onNutrition,
      ),
      _QuickActionCard(
        label: 'AI Coach',
        description: 'Ask anything',
        icon: Icons.smart_toy_outlined,
        color: Colors.amberAccent,
        completion: 0.34,
        index: 2,
        controller: controller,
        onTap: onAi,
      ),
      _QuickActionCard(
        label: 'Exercises',
        description: 'Browse library',
        icon: Icons.list_alt,
        color: Colors.purpleAccent,
        completion: 0.48,
        index: 3,
        controller: controller,
        onTap: onExercises,
      ),
    ];

    final grid = GridView.count(
      crossAxisCount: isNarrow ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isNarrow ? 1.8 : 2.1,
      children: cards,
    );

    return _ShakeOnError(hasError: hasError, child: grid);
  }
}

Route<T> _slideRightRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      );
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

void _showErrorSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: onRetry,
      ),
    ),
  );
}

class _QuickActionCard extends StatefulWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final double completion;
  final bool isActive;
  final int index;
  final AnimationController controller;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.completion,
    required this.index,
    required this.controller,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(
        0.1 * (widget.index + 1),
        0.7 + 0.1 * widget.index,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(anim),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: _pressed ? 0.95 : 1,
            duration: const Duration(milliseconds: 120),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                splashColor: widget.color.withOpacity(0.28),
                highlightColor: widget.color.withOpacity(0.18),
                onHighlightChanged: (v) {
                  setState(() => _pressed = v);
                },
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withOpacity(0.18),
                        widget.color.withOpacity(0.32),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 40,
                              width: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                value: widget.completion,
                                backgroundColor:
                                    Colors.white.withOpacity(0.25),
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              height: 28,
                              width: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                widget.icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white70,
                                          ),
                                    ),
                                  ),
                                  if (widget.isActive)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                      child: const Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoveryHabitsCard extends StatefulWidget {
  final List<_Habit> habits;
  final bool isLoading;
  final void Function(String id) onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _RecoveryHabitsCard({
    required this.habits,
    required this.isLoading,
    required this.onToggle,
    required this.onReorder,
  });

  @override
  State<_RecoveryHabitsCard> createState() => _RecoveryHabitsCardState();
}

class _RecoveryHabitsCardState extends State<_RecoveryHabitsCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(height: 20, width: 120),
            SizedBox(height: 12),
            _SkeletonBox(height: 52),
            SizedBox(height: 8),
            _SkeletonBox(height: 52),
            SizedBox(height: 8),
            _SkeletonBox(height: 52),
          ],
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.08),
              ),
              child: const Icon(
                Icons.self_improvement,
                color: Colors.white,
              ),
            ),
            title: Text(
              'Mobility, breathing, sleep',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            subtitle: Text(
              'Stack small wins to boost recovery.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            trailing: IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() => _expanded = !_expanded);
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.habits.length,
                    onReorder: widget.onReorder,
                    itemBuilder: (context, index) {
                      final habit = widget.habits[index];
                      return _HabitTile(
                        key: ValueKey(habit.id),
                        habit: habit,
                        onToggle: () => widget.onToggle(habit.id),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final _Habit habit;
  final VoidCallback onToggle;

  const _HabitTile({super.key, required this.habit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: GestureDetector(
        onTap: onToggle,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: habit.isCompleted
              ? const Icon(
                  Icons.check_circle,
                  key: ValueKey('done'),
                  color: Colors.greenAccent,
                )
              : const Icon(
                  Icons.radio_button_unchecked,
                  key: ValueKey('todo'),
                  color: Colors.white70,
                ),
        ),
      ),
      title: Text(
        habit.title,
        style: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.subtitle,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: habit.progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
            ),
          ),
        ],
      ),
      trailing: const Icon(
        Icons.drag_handle,
        color: Colors.white38,
      ),
    );
  }
}

class _Habit {
  final String id;
  final String title;
  final String subtitle;
  double progress;
  bool isCompleted;

  _Habit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.isCompleted = false,
  });
}

class _TemplatePlanCard extends StatelessWidget {
  final String? workoutTemplate;
  final String? nutritionTemplate;

  const _TemplatePlanCard({
    this.workoutTemplate,
    this.nutritionTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasWorkout = workoutTemplate != null;
    final hasNutrition = nutritionTemplate != null;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (rect) => AppTheme.heroGradient()
                .createShader(rect),
            child: Text(
              'Active plans',
              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (hasWorkout)
            Row(
              children: [
                const Icon(
                  Icons.fitness_center,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Workout: $workoutTemplate',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          if (hasWorkout && hasNutrition) const SizedBox(height: 6),
          if (hasNutrition)
            Row(
              children: [
                const Icon(
                  Icons.restaurant,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nutrition: $nutritionTemplate',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Swipe to see full schedule in plan screens.',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Navigate to profile / plan edit.
                  Navigator.pushNamed(context, '/profile');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.orange.withOpacity(0.22),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.wifi_off, color: Colors.orangeAccent, size: 16),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _BellReminderIcon extends StatefulWidget {
  const _BellReminderIcon();

  @override
  State<_BellReminderIcon> createState() => _BellReminderIconState();
}

class _BellReminderIconState extends State<_BellReminderIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween(begin: -0.02, end: 0.02).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: const Icon(Icons.notifications_active,
          color: Colors.white70, size: 22),
    );
  }
}

class _ShakeOnError extends StatefulWidget {
  final bool hasError;
  final Widget child;

  const _ShakeOnError({required this.hasError, required this.child});

  @override
  State<_ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<_ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(covariant _ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.hasError && widget.hasError) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = Tween(begin: -8.0, end: 8.0).chain(
      CurveTween(curve: Curves.elasticIn),
    ).animate(_controller);

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(anim.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(height: 20, width: 160),
                SizedBox(height: 8),
                _SkeletonBox(height: 16, width: 200),
                SizedBox(height: 10),
                _SkeletonBox(height: 16, width: 80),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(height: 72, width: 72, borderRadius: 999),
        ],
      ),
    );
  }
}

class _ProgressRingSkeleton extends StatelessWidget {
  const _ProgressRingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _SkeletonBox(height: 140, width: 140, borderRadius: 999),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const _SkeletonBox({
    required this.height,
    this.width,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.white),
      ),
    );
  }
}
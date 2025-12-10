import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_state.dart';
import '../../widgets/fitness_page.dart';

enum _Phase { prep, active, rest, complete }

class AiWorkoutScreen extends StatefulWidget {
  const AiWorkoutScreen({super.key});

  @override
  State<AiWorkoutScreen> createState() => _AiWorkoutScreenState();
}

class _AiWorkoutScreenState extends State<AiWorkoutScreen>
    with TickerProviderStateMixin {
  final Map<String, Map<String, List<String>>> _cachedPlans = {};
  final Set<String> _equipment = {};
  final Set<String> _muscleFocus = {};

  String _goal = 'fat_loss';
  int _days = 3;
  String _duration = '30';
  Map<String, List<String>>? _plan;
  bool _loadingPlan = false;
  String? _error;
  int _selectedDayIndex = 0;

  // Session state
  _Phase _phase = _Phase.prep;
  int _currentExercise = 0;
  int _currentSet = 1;
  int _totalSets = 3;
  int _reps = 0;
  int _activeTimer = 0;
  int _restSeconds = 45;
  int _warmupSeconds = 10;
  bool _autoAdvance = true;
  DateTime? _sessionStart;
  Duration _elapsed = Duration.zero;
  final List<String> _completed = [];
  bool _resumeAvailable = false;
  bool _waterReminder = false;
  int _bestCompleted = 0;

  late AnimationController _warmupController;
  late AnimationController _restController;
  late AnimationController _confettiController;

  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _warmupController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _warmupSeconds),
    );
    _restController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _restSeconds),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _restoreSession();
  }

  @override
  void dispose() {
    _warmupController.dispose();
    _restController.dispose();
    _confettiController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ai_session_state');
    _bestCompleted = prefs.getInt('ai_best_completed') ?? 0;
    if (saved == null || saved.isEmpty) return;
    try {
      final parts = saved.split('|');
      if (parts.length < 6) return;
      setState(() {
        _resumeAvailable = true;
        _goal = parts[0];
        _days = int.tryParse(parts[1]) ?? _days;
        _duration = parts[2];
        _selectedDayIndex = int.tryParse(parts[3]) ?? 0;
        _currentExercise = int.tryParse(parts[4]) ?? 0;
        _currentSet = int.tryParse(parts[5]) ?? 1;
      });
    } catch (_) {
      // ignore invalid data
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final value =
        '$_goal|$_days|$_duration|$_selectedDayIndex|$_currentExercise|$_currentSet';
    await prefs.setString('ai_session_state', value);
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_session_state');
  }

  Future<void> _persistBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ai_best_completed', _bestCompleted);
  }

  void _startWarmup() {
    setState(() {
      _phase = _Phase.prep;
      _warmupSeconds = 10;
    });
    _warmupController.duration = Duration(seconds: _warmupSeconds);
    _warmupController.forward(from: 0);
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining =
          _warmupSeconds - (_warmupController.value * _warmupSeconds).round();
      if (remaining <= 3 && remaining > 0) {
        HapticFeedback.mediumImpact();
      }
      if (_warmupController.isCompleted) {
        timer.cancel();
        _startExercise();
      }
      setState(() {});
    });
  }

  void _startExercise() {
    setState(() {
      _phase = _Phase.active;
      _activeTimer = 0;
      _reps = 0;
      _sessionStart ??= DateTime.now();
    });
    _persistSession();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _activeTimer += 1;
        _elapsed = DateTime.now().difference(_sessionStart ?? DateTime.now());
        if (_activeTimer == 50) {
          SemanticsService.announce(
            '10 seconds left',
            TextDirection.ltr,
          );
        }
      });
    });
  }

  void _startRest({int? seconds}) {
    _restSeconds = seconds ?? _restSeconds;
    _restController.duration = Duration(seconds: _restSeconds);
    _restController.forward(from: 0);
    setState(() => _phase = _Phase.rest);
    _waterReminder = _completed.length > 0 && _completed.length % 3 == 0;
    _persistSession();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining =
          _restSeconds - (_restController.value * _restSeconds).round();
      if (remaining <= 3 && remaining > 0) {
        HapticFeedback.mediumImpact();
      }
      if (_restController.isCompleted) {
        timer.cancel();
        if (_autoAdvance) _nextExercise();
      }
      setState(() {});
    });
  }

  void _completeWorkout(AppState appState) {
    _tickTimer?.cancel();
    setState(() => _phase = _Phase.complete);
    _confettiController.forward(from: 0);
    if (_completed.length > _bestCompleted) {
      _bestCompleted = _completed.length;
      _persistBest();
    }
    final summary = {
      'goal': _goal,
      'days': _days,
      'duration': _duration,
      'completed': _completed,
      'elapsed_sec': _elapsed.inSeconds,
      'date': DateTime.now().toIso8601String(),
    };
    appState.logWorkout(summary);
    _clearPersistedSession();
  }

  void _nextExercise() {
    final exercises = _currentDayExercises;
    if (_currentExercise >= exercises.length - 1) {
      _completeWorkout(context.read<AppState>());
      return;
    }
    setState(() {
      _completed.add(exercises[_currentExercise]);
      _currentExercise += 1;
      _currentSet = 1;
    });
    _persistSession();
    _startExercise();
  }

  void _skipExercise() {
    _nextExercise();
  }

  void _incrementSet() {
    setState(() {
      if (_currentSet < _totalSets) {
        _currentSet += 1;
      } else {
        _startRest();
      }
    });
    _persistSession();
  }

  List<String> get _currentDayExercises {
    if (_plan == null || _plan!.isEmpty) return [];
    final key = _plan!.keys.elementAt(_selectedDayIndex);
    return _plan![key] ?? [];
  }

  Future<void> _generatePlan(AppState appState) async {
    final cacheKey = '$_goal-$_days-$_duration-${_equipment.join(',')}';
    if (_cachedPlans.containsKey(cacheKey)) {
      setState(() {
        _plan = _cachedPlans[cacheKey];
        _error = null;
      });
      _persistSession();
      return;
    }
    setState(() {
      _loadingPlan = true;
      _error = null;
    });
    try {
      final plan = await appState.generateWorkoutPlanAi(
        goal: _goal,
        daysPerWeek: _days,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _cachedPlans[cacheKey] = plan;
        _selectedDayIndex = 0;
      });
      _persistSession();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loadingPlan = false);
    }
  }

  void _resetSession() {
    _tickTimer?.cancel();
    setState(() {
      _phase = _Phase.prep;
      _currentExercise = 0;
      _currentSet = 1;
      _elapsed = Duration.zero;
      _completed.clear();
      _sessionStart = null;
      _activeTimer = 0;
    });
    _startWarmup();
    _persistSession();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final textTheme = Theme.of(context).textTheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return FitnessPage(
      appBar: AppBar(
        title: const Text('AI Workout Coach'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      scrollable: false,
      child: Column(
        children: [
          _buildGenerator(textTheme, appState),
          const SizedBox(height: 12),
          _plan == null
              ? _buildEmpty(textTheme)
              : Expanded(
                  child: Column(
                    children: [
                      _buildWeekCalendar(textTheme),
                      const SizedBox(height: 10),
                      Expanded(
                        child: isLandscape
                            ? Row(
                                children: [
                                  Expanded(child: _buildExerciseList(textTheme)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildSessionView(textTheme)),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(child: _buildExerciseList(textTheme)),
                                  const SizedBox(height: 10),
                                  _buildSessionView(textTheme),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText.rich(
                TextSpan(
                  text: 'Error: ',
                  style: const TextStyle(color: Colors.redAccent),
                  children: [
                    TextSpan(
                      text: _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenerator(TextTheme textTheme, AppState appState) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'AI Workout Plan',
            subtitle: 'Customize goals, time, equipment, and focus.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                'fat_loss': Icons.local_fire_department,
                'muscle_gain': Icons.fitness_center,
                'general': Icons.favorite,
                'flexibility': Icons.self_improvement,
              }.entries)
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.value, size: 18),
                      const SizedBox(width: 6),
                      Text(entry.key.replaceAll('_', ' ')),
                    ],
                  ),
                  selected: _goal == entry.key,
                  onSelected: (_) => setState(() => _goal = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Days per week: $_days',
                        style: const TextStyle(color: Colors.white)),
                    Slider(
                      value: _days.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      onChanged: (v) => setState(() => _days = v.round()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _duration,
                  decoration:
                      const InputDecoration(labelText: 'Session duration (min)'),
                  items: const [
                    DropdownMenuItem(value: '15', child: Text('15')),
                    DropdownMenuItem(value: '30', child: Text('30')),
                    DropdownMenuItem(value: '45', child: Text('45')),
                    DropdownMenuItem(value: '60', child: Text('60+')),
                  ],
                  onChanged: (v) => setState(() => _duration = v ?? '30'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _chipsRow(
            label: 'Equipment available',
            values: const ['Dumbbells', 'Barbell', 'Bands', 'Bench', 'None'],
            selected: _equipment,
            onToggle: (v) {
              setState(() {
                if (_equipment.contains(v)) {
                  _equipment.remove(v);
                } else {
                  _equipment.add(v);
                }
              });
              _persistSession();
            },
          ),
          const SizedBox(height: 10),
          _chipsRow(
            label: 'Muscle focus',
            values: const ['Chest', 'Back', 'Legs', 'Core', 'Arms', 'Shoulders'],
            selected: _muscleFocus,
            onToggle: (v) {
              setState(() {
                if (_muscleFocus.contains(v)) {
                  _muscleFocus.remove(v);
                } else {
                  _muscleFocus.add(v);
                }
              });
              _persistSession();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _loadingPlan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loadingPlan ? 'Generating...' : 'Generate plan'),
                  onPressed:
                      _loadingPlan ? null : () => _generatePlan(appState),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _plan == null ? null : _resetSession,
                child: const Text('Start session'),
              ),
              if (_resumeAvailable && _plan != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton(
                    onPressed: () {
                      _startWarmup();
                      setState(() => _resumeAvailable = false);
                    },
                    child: const Text('Resume'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(TextTheme textTheme) {
    return Expanded(
      child: Center(
        child: Text(
          _loadingPlan
              ? 'Generating plan...'
              : 'Generate a plan to start your AI-guided workout.',
          style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildWeekCalendar(TextTheme textTheme) {
    final days = _plan!.keys.toList();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = days[index];
          final selected = index == _selectedDayIndex;
          final exercises = _plan![name] ?? [];
          return AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: selected ? 1.03 : 1.0,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedDayIndex = index;
                _currentExercise = 0;
                _completed.clear();
              }),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: textTheme.titleMedium
                            ?.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _pill('${exercises.length} exercises'),
                          const SizedBox(width: 6),
                          _pill('${_duration}m'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildExerciseList(TextTheme textTheme) {
    final exercises = _currentDayExercises;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Today\'s session',
            subtitle: 'Tap to preview or skip ahead.',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final name = exercises[index];
                final isCurrent = index == _currentExercise;
                final done = index < _currentExercise;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent
                          ? Colors.white
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle
                            : isCurrent
                                ? Icons.play_circle
                                : Icons.radio_button_unchecked,
                        color: done
                            ? Colors.greenAccent
                            : isCurrent
                                ? Colors.amber
                                : Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: textTheme.bodyLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentExercise = index;
                            _currentSet = 1;
                          });
                          _startExercise();
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView(TextTheme textTheme) {
    final exercises = _currentDayExercises;
    final currentName =
        exercises.isEmpty ? 'No exercise' : exercises[_currentExercise];
    final estCalories =
        (_elapsed.inMinutes.clamp(1, 500) * 6).clamp(10, 4000);
    return Stack(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Execution',
                    style: textTheme.titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  _pill(_phase.name.toUpperCase()),
                ],
              ),
              const SizedBox(height: 10),
              _ExerciseExecutionCard(
                title: currentName,
                setLabel: 'Set $_currentSet/$_totalSets',
                reps: _reps,
                timerSeconds: _activeTimer,
                onIncRep: () => setState(() => _reps += 1),
                onDecRep: () =>
                    setState(() => _reps = (_reps - 1).clamp(0, 999)),
                onMarkSet: _incrementSet,
                onSkip: _skipExercise,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start warm-up'),
                      onPressed: _startWarmup,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.flag),
                      label: const Text('Mark complete'),
                      onPressed: () =>
                          _completeWorkout(context.read<AppState>()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_phase == _Phase.rest) _RestOverlay(
          seconds: _restSeconds,
          controller: _restController,
          nextExercise: _currentExercise + 1 < exercises.length
              ? exercises[_currentExercise + 1]
              : 'Finish',
          onSkip: _startExercise,
          onAdjust: (delta) {
            final updated = (_restSeconds + delta).clamp(30, 90);
            _startRest(seconds: updated);
          },
          waterReminder: _waterReminder,
        ),
        if (_phase == _Phase.prep) _WarmupOverlay(controller: _warmupController),
        if (_phase == _Phase.complete)
          _CompletionOverlay(
            controller: _confettiController,
            elapsed: _elapsed,
            completed: _completed,
            estimatedCalories: estCalories,
            bestCompleted: _bestCompleted,
          ),
      ],
    );
  }

  Widget _chipsRow({
    required String label,
    required List<String> values,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (v) => FilterChip(
                  label: Text(v),
                  selected: selected.contains(v),
                  onSelected: (_) => onToggle(v),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ExerciseExecutionCard extends StatelessWidget {
  const _ExerciseExecutionCard({
    required this.title,
    required this.setLabel,
    required this.reps,
    required this.timerSeconds,
    required this.onIncRep,
    required this.onDecRep,
    required this.onMarkSet,
    required this.onSkip,
  });

  final String title;
  final String setLabel;
  final int reps;
  final int timerSeconds;
  final VoidCallback onIncRep;
  final VoidCallback onDecRep;
  final VoidCallback onMarkSet;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final minutes = (timerSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (timerSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(setLabel, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(Icons.fitness_center, color: Colors.white54, size: 56),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bigBtn(icon: Icons.remove, onTap: onDecRep),
              Expanded(
                child: Column(
                  children: [
                    const Text('Reps', style: TextStyle(color: Colors.white70)),
                    Text(
                      reps.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _bigBtn(icon: Icons.add, onTap: onIncRep),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Timer',
                        style: TextStyle(color: Colors.white70)),
                    Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: const [
                    Text('Form tips',
                        style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 6),
                    Text(
                      'Keep core tight. Control tempo. Breathe out on effort.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onMarkSet,
                  child: const Text('Mark set complete'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Skip exercise'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 64,
          width: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _RestOverlay extends StatelessWidget {
  const _RestOverlay({
    required this.seconds,
    required this.controller,
    required this.nextExercise,
    required this.onSkip,
    required this.onAdjust,
    required this.waterReminder,
  });

  final int seconds;
  final AnimationController controller;
  final String nextExercise;
  final VoidCallback onSkip;
  final ValueChanged<int> onAdjust;
  final bool waterReminder;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 220),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Rest',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                width: 160,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    final progress = controller.value;
                    final remaining = (seconds * (1 - progress)).ceil();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1 - progress,
                          strokeWidth: 10,
                          color: Colors.greenAccent,
                          backgroundColor: Colors.white24,
                        ),
                        Text(
                          '$remaining s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Next: $nextExercise',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              if (waterReminder) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.water_drop, color: Colors.cyanAccent),
                      SizedBox(width: 8),
                      Text(
                        'Hydrate break! Sip some water.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => onAdjust(-15),
                    icon: const Icon(Icons.remove, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => onAdjust(15),
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip rest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarmupOverlay extends StatelessWidget {
  const _WarmupOverlay({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final remaining =
                  (controller.duration!.inSeconds * (1 - controller.value))
                      .ceil();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Warm-up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Quick mobility and breathing. Get ready!',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompletionOverlay extends StatelessWidget {
  const _CompletionOverlay({
    required this.controller,
    required this.elapsed,
    required this.completed,
    required this.estimatedCalories,
    required this.bestCompleted,
  });

  final AnimationController controller;
  final Duration elapsed;
  final List<String> completed;
  final int estimatedCalories;
  final int bestCompleted;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final rnd = Random();
                  final dots = List.generate(
                    80,
                    (_) => Offset(
                      rnd.nextDouble() * MediaQuery.of(context).size.width,
                      rnd.nextDouble() *
                          MediaQuery.of(context).size.height *
                          controller.value,
                    ),
                  );
                  return CustomPaint(
                    painter: _ConfettiPainter(dots: dots),
                  );
                },
              ),
            ),
            Center(
              child: GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Workout Complete!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Time: ${minutes}m ${seconds}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Exercises done: ${completed.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estimated calories: ~$estimatedCalories kcal',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (completed.length >= bestCompleted &&
                        completed.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emoji_events,
                                color: Colors.orangeAccent),
                            SizedBox(width: 8),
                            Text(
                              'Personal record!',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showShareDialog(context),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rate difficulty',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: 0.5,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.save),
                      label: const Text('Save to history'),
                    ),
                    const SizedBox(height: 6),
                    _CooldownSuggestion(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Share workout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Share as image or text. (Implementation placeholder)',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.dots});

  final List<Offset> dots;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final colors = [
      Colors.pinkAccent,
      Colors.amber,
      Colors.lightBlueAccent,
      Colors.greenAccent,
    ];
    for (var i = 0; i < dots.length; i++) {
      paint.color = colors[i % colors.length];
      canvas.drawCircle(dots[i], 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _CooldownSuggestion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.self_improvement, color: Colors.lightBlueAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Start a 5-minute cooldown: breathing + stretching.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          Icon(Icons.play_circle, color: Colors.white70),
        ],
      ),
    );
  }
}
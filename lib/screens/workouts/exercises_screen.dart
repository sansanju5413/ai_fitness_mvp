import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exercise.dart';
import '../../providers/app_state.dart';
import '../../widgets/fitness_page.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _favorites = <String>{};
  final Map<String, double> _weightLog = {};
  final Map<String, int> _repLog = {};
  Timer? _debounce;
  bool _showFilters = false;
  String _search = '';
  String? _selectedCategory;
  String? _selectedMuscle;
  String? _selectedEquipment;
  String? _selectedDifficulty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _search = value.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final exercises = appState.exercises;
    final textTheme = Theme.of(context).textTheme;

    final muscles = exercises.map((e) => e.muscleGroup).toSet().toList();
    final equipments = exercises.map((e) => e.equipment).toSet().toList();
    final difficulties = exercises.map((e) => e.difficulty).toSet().toList();

    final filtered = exercises.where((ex) {
      final matchesSearch = _search.isEmpty ||
          ex.name.toLowerCase().contains(_search) ||
          ex.description.toLowerCase().contains(_search);
      final matchesCategory =
          _selectedCategory == null || ex.muscleGroup == _selectedCategory;
      final matchesMuscle =
          _selectedMuscle == null || ex.muscleGroup == _selectedMuscle;
      final matchesEquipment =
          _selectedEquipment == null || ex.equipment == _selectedEquipment;
      final matchesDifficulty =
          _selectedDifficulty == null || ex.difficulty == _selectedDifficulty;
      return matchesSearch &&
          matchesCategory &&
          matchesMuscle &&
          matchesEquipment &&
          matchesDifficulty;
    }).toList();

    return FitnessPage(
      appBar: AppBar(
        title: const Text('Exercise library'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _buildFab(),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(textTheme),
              const SizedBox(height: 12),
              _buildCategoryScroller(muscles),
              const SizedBox(height: 8),
              _buildFilterRow(textTheme, muscles, equipments, difficulties),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Center(
                  child: SelectableText.rich(
                    const TextSpan(
                      text:
                          'No exercises match your filters.\nTry clearing filters.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                _buildGrid(filtered, textTheme),
              const SizedBox(height: 140),
            ],
          ),
          _buildAnimatedFilterPanel(muscles, equipments, difficulties),
        ],
      ),
    );
  }

  Widget _buildSearchBar(TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search exercises',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () => setState(() => _showFilters = !_showFilters),
          icon: AnimatedRotation(
            turns: _showFilters ? 0.5 : 0,
            duration: const Duration(milliseconds: 240),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryScroller(List<String> muscles) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: muscles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final muscle = muscles[index];
          final isSelected = muscle == _selectedCategory;
          return ChoiceChip(
            label: Text(
              muscle,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
            selected: isSelected,
            onSelected: (v) =>
                setState(() => _selectedCategory = v ? muscle : null),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.12),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow(
    TextTheme textTheme,
    List<String> muscles,
    List<String> equipments,
    List<String> difficulties,
  ) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: _selectedMuscle ?? 'Muscle group',
                icon: Icons.fitness_center,
                onTap: () => setState(() {
                  _selectedMuscle = _selectedMuscle == null
                      ? _firstOrNull(muscles)
                      : null;
                }),
              ),
              _filterChip(
                label: _selectedEquipment ?? 'Equipment',
                icon: Icons.handyman,
                onTap: () => setState(() {
                  _selectedEquipment = _selectedEquipment == null
                      ? _firstOrNull(equipments)
                      : null;
                }),
              ),
              _filterChip(
                label: _selectedDifficulty ?? 'Difficulty',
                icon: Icons.auto_graph,
                onTap: () => setState(() {
                  _selectedDifficulty = _selectedDifficulty == null
                      ? _firstOrNull(difficulties)
                      : null;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Exercise> items, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final crossAxisCount = isWide ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 1.9 : 1.2,
          ),
          itemBuilder: (context, index) {
            final ex = items[index];
            return _ExerciseCard(
              exercise: ex,
              isFavorite: _favorites.contains(ex.id),
              weight: _weightLog[ex.id] ?? 0,
              reps: _repLog[ex.id] ?? 0,
              onToggleFavorite: () {
                setState(() {
                  if (_favorites.contains(ex.id)) {
                    _favorites.remove(ex.id);
                  } else {
                    _favorites.add(ex.id);
                  }
                });
              },
              onLogWeight: (value) =>
                  setState(() => _weightLog[ex.id] = value),
              onLogReps: (value) => setState(() => _repLog[ex.id] = value),
            );
          },
        );
      },
    );
  }

  Widget _buildAnimatedFilterPanel(
    List<String> muscles,
    List<String> equipments,
    List<String> difficulties,
  ) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      bottom: _showFilters ? 0 : -240,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showFilters,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showFilters ? 1 : 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.86),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showFilters = false),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _chipsRow(
                  'Muscle group',
                  muscles,
                  _selectedMuscle,
                  (v) => setState(() => _selectedMuscle = v),
                ),
                const SizedBox(height: 10),
                _chipsRow(
                  'Equipment',
                  equipments,
                  _selectedEquipment,
                  (v) => setState(() => _selectedEquipment = v),
                ),
                const SizedBox(height: 10),
                _chipsRow(
                  'Difficulty',
                  difficulties,
                  _selectedDifficulty,
                  (v) => setState(() => _selectedDifficulty = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedMuscle = null;
                            _selectedEquipment = null;
                            _selectedDifficulty = null;
                            _selectedCategory = null;
                            _showFilters = false;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showFilters = false),
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipsRow(
    String label,
    List<String> values,
    String? selected,
    ValueChanged<String?> onChanged,
  ) {
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
                (v) => ChoiceChip(
                  selected: selected == v,
                  label: Text(v),
                  onSelected: (sel) => onChanged(sel ? v : null),
                  selectedColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected == v ? Colors.black : Colors.white,
                  ),
                  backgroundColor: Colors.white.withOpacity(0.12),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () {},
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Custom Workout'),
    );
  }

  String? _firstOrNull(List<String> list) {
    if (list.isEmpty) return null;
    return list.first;
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.isFavorite,
    required this.weight,
    required this.reps,
    required this.onToggleFavorite,
    required this.onLogWeight,
    required this.onLogReps,
  });

  final Exercise exercise;
  final bool isFavorite;
  final double weight;
  final int reps;
  final VoidCallback onToggleFavorite;
  final ValueChanged<double> onLogWeight;
  final ValueChanged<int> onLogReps;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _toggleExpand,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    height: 82,
                    width: 82,
                    child: const Icon(Icons.image, color: Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _tag(ex.muscleGroup, Colors.tealAccent),
                            _tag(ex.equipment, Colors.amberAccent),
                            _difficultyBadge(ex.difficulty),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onToggleFavorite,
                    icon: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: widget.isFavorite ? 1.2 : 1,
                      child: Icon(
                        widget.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOut,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      ex.description,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _FormTipsAccordion(tips: [
                      'Focus on controlled tempo.',
                      'Keep spine neutral.',
                      'Exhale on effort.',
                    ]),
                    const SizedBox(height: 10),
                    _InlineLogger(
                      weight: widget.weight,
                      reps: widget.reps,
                      onWeightChanged: widget.onLogWeight,
                      onRepsChanged: widget.onLogReps,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showDetails(context, ex),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Details & Variations'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _difficultyBadge(String difficulty) {
    final icon = difficulty.toLowerCase().contains('begin')
        ? Icons.spa
        : difficulty.toLowerCase().contains('inter')
            ? Icons.show_chart
            : Icons.local_fire_department;
    final color = difficulty.toLowerCase().contains('begin')
        ? Colors.greenAccent
        : difficulty.toLowerCase().contains('inter')
            ? Colors.blueAccent
            : Colors.redAccent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          difficulty,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context, Exercise ex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.92),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ex.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ShimmerBox(
                    height: 200,
                    width: double.infinity,
                    child: const Icon(Icons.movie, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Step-by-step instructions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.white24,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ex.description,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Common mistakes: avoid rounding your back and rushing reps.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Variations',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return _ShimmerBox(
                          height: 120,
                          width: 160,
                          child: Center(
                            child: Text(
                              index.isEven ? 'Easier' : 'Harder',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Target muscles',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MuscleDiagram(),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Add to Workout'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.height,
    required this.width,
    this.child,
  });

  final double height;
  final double width;
  final Widget? child;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ShimmerPainter(progress: _controller.value),
            child: Container(
              height: widget.height,
              width: widget.width,
              alignment: Alignment.center,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.24),
          Colors.white.withOpacity(0.06),
        ],
        stops: const [0, 0.5, 1],
        begin: Alignment(-1 + progress * 2, -1),
        end: Alignment(1 + progress * 2, 1),
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FormTipsAccordion extends StatefulWidget {
  const _FormTipsAccordion({required this.tips});

  final List<String> tips;

  @override
  State<_FormTipsAccordion> createState() => _FormTipsAccordionState();
}

class _FormTipsAccordionState extends State<_FormTipsAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              const Text(
                'Form tips',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.tips
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• $tip',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                )
                .toList(),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _InlineLogger extends StatelessWidget {
  const _InlineLogger({
    required this.weight,
    required this.reps,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  final double weight;
  final int reps;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberPicker(
            label: 'Weight (kg)',
            value: weight,
            onChanged: onWeightChanged,
            step: 2.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RepCounter(
            reps: reps,
            onChanged: onRepsChanged,
          ),
        ),
      ],
    );
  }
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.step,
  });

  final String label;
  final double value;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              _circleBtn(
                icon: Icons.remove,
                onTap: () => onChanged((value - step).clamp(0, 999)),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _circleBtn(
                icon: Icons.add,
                onTap: () => onChanged(value + step),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        height: 36,
        width: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _RepCounter extends StatelessWidget {
  const _RepCounter({required this.reps, required this.onChanged});

  final int reps;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reps', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              _btn(Icons.remove, () => onChanged((reps - 1).clamp(0, 200))),
              Expanded(
                child: Center(
                  child: Text(
                    reps.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _btn(Icons.add, () => onChanged(reps + 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        height: 36,
        width: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white24,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _MuscleDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(
        painter: _MusclePainter(),
        child: const Center(
          child: Text(
            'Muscle map',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _MusclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final rect =
        Rect.fromCenter(center: size.center(Offset.zero), width: 90, height: 140);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)), paint);
    final highlight = Paint()
      ..color = Colors.pinkAccent.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(rect.topCenter + const Offset(0, 28), 18, highlight);
    canvas.drawCircle(rect.center, 22, highlight);
    canvas.drawCircle(rect.bottomCenter - const Offset(0, 28), 16, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
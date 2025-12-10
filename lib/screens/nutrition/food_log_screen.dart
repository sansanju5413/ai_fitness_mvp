import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/food_item.dart';
import '../../providers/app_state.dart';
import '../../widgets/fitness_page.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _manualNameCtrl = TextEditingController();
  final TextEditingController _manualCaloriesCtrl = TextEditingController();
  final TextEditingController _manualProteinCtrl = TextEditingController();
  final TextEditingController _manualCarbCtrl = TextEditingController();
  final TextEditingController _manualFatCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<FoodItem> _results = [];
  List<FoodItem> _recentFoods = [];
  Set<String> _favoriteIds = {};
  List<String> _recentSearches = [];
  bool _loading = false;
  bool _showSkeleton = false;
  String _selectedCategory = 'All';
  String? _error;
  FoodItem? _pendingAdd;
  double _pendingServing = 1;

  // Meal builder staging
  final List<_MealDraftItem> _draftItems = [];
  String _draftMealName = 'My meal';

  // History mock
  DateTime _selectedDay = DateTime.now();
  final Map<DateTime, List<_LoggedMeal>> _history = {};

  // Tabs
  int _tabIndex = 0; // 0 search, 1 recent/fav, 2 history

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _manualNameCtrl.dispose();
    _manualCaloriesCtrl.dispose();
    _manualProteinCtrl.dispose();
    _manualCarbCtrl.dispose();
    _manualFatCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _showSkeleton = true;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    final appState = context.read<AppState>();
    final foods = appState.foods;
    final filtered = foods.where((f) {
      final match = f.name.toLowerCase().contains(query);
      final category = _categoryForFood(f);
      final categoryMatch =
          _selectedCategory == 'All' || category == _selectedCategory;
      return match && categoryMatch;
    }).toList();
    if (!mounted) return;
    setState(() {
      _results = filtered;
      _loading = false;
      _showSkeleton = false;
      if (query.isNotEmpty && !_recentSearches.contains(query)) {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 6) {
          _recentSearches.removeLast();
        }
      }
    });
  }

  void _addToRecent(FoodItem item) {
    _recentFoods.removeWhere((f) => f.id == item.id);
    _recentFoods.insert(0, item);
    if (_recentFoods.length > 8) {
      _recentFoods.removeLast();
    }
  }

  Future<void> _logFood(
    FoodItem item,
    double servings, {
    String meal = 'unspecified',
  }) async {
    try {
      final calories = item.calories * servings;
      final log = {
        'foodId': item.id,
        'name': item.name,
        'quantity': servings,
        'servingSize': item.servingSize,
        'unit': item.unit,
        'calories': calories,
        'protein': item.protein * servings,
        'carbs': item.carbs * servings,
        'fat': item.fat * servings,
        'meal': meal,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await context.read<AppState>().logFood(log);
      _addToRecent(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} logged')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _openManualEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: _ManualEntryForm(
            nameCtrl: _manualNameCtrl,
            caloriesCtrl: _manualCaloriesCtrl,
            proteinCtrl: _manualProteinCtrl,
            carbCtrl: _manualCarbCtrl,
            fatCtrl: _manualFatCtrl,
            onSave: (custom) {
              Navigator.of(context).pop();
              _logFood(custom, 1, meal: 'Custom');
            },
          ),
        );
      },
    );
  }

  void _toggleFavorite(FoodItem item) {
    setState(() {
      if (_favoriteIds.contains(item.id)) {
        _favoriteIds.remove(item.id);
      } else {
        _favoriteIds.add(item.id);
      }
    });
  }

  void _addToMealBuilder(FoodItem item, double servings) {
    setState(() {
      _draftItems.add(_MealDraftItem(item: item, servings: servings));
    });
  }

  void _removeDraft(int index) {
    setState(() {
      _draftItems.removeAt(index);
    });
  }

  double get _draftCalories => _draftItems.fold(
        0,
        (p, e) => p + e.item.calories * e.servings,
      );

  double get _draftProtein => _draftItems.fold(
        0,
        (p, e) => p + e.item.protein * e.servings,
      );

  double get _draftCarbs => _draftItems.fold(
        0,
        (p, e) => p + e.item.carbs * e.servings,
      );

  double get _draftFats => _draftItems.fold(
        0,
        (p, e) => p + e.item.fat * e.servings,
      );

  Future<void> _logDraftMeal() async {
    if (_draftItems.isEmpty) return;
    for (final item in _draftItems) {
      await _logFood(item.item, item.servings, meal: _draftMealName);
    }
    setState(() {
      _draftItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final foods = appState.foods;
    final baseList =
        _results.isEmpty && _searchCtrl.text.isEmpty ? foods : _results;

    return FitnessPage(
      appBar: AppBar(
        title: const Text('Food Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchBar(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            recentSearches: _recentSearches,
            onRecentTap: (v) {
              _searchCtrl.text = v;
              _runSearch();
            },
            onOpenManual: _openManualEntry,
            onCategoryChanged: (c) {
              setState(() => _selectedCategory = c);
              _runSearch();
            },
            selectedCategory: _selectedCategory,
          ),
          const SizedBox(height: 12),
          _TabSwitcher(
            index: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            SelectableText.rich(
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
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tabIndex == 0
                  ? _buildSearchResults(baseList)
                  : _tabIndex == 1
                      ? _RecentFavorites(
                          recentFoods: _recentFoods,
                          favoriteIds: _favoriteIds,
                          onAdd: _logFood,
                          onFavoriteToggle: _toggleFavorite,
                        )
                      : _HistoryView(
                          selectedDay: _selectedDay,
                          onDaySelected: (d) => setState(() {
                            _selectedDay = d;
                          }),
                          history: _history,
                          onCopyToToday: (meal) async {
                            await _logFood(meal.item, meal.servings);
                          },
                        ),
            ),
          ),
          const SizedBox(height: 10),
          _MealBuilder(
            items: _draftItems,
            onRemove: _removeDraft,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _draftItems.removeAt(oldIndex);
                _draftItems.insert(newIndex, item);
              });
            },
            onNameChanged: (v) => setState(() => _draftMealName = v),
            mealName: _draftMealName,
            totals: (_draftCalories, _draftProtein, _draftCarbs, _draftFats),
            onLogMeal: _logDraftMeal,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<FoodItem> foods) {
    if (_showSkeleton) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }
    if (foods.isEmpty) {
      return Center(
        child: Text(
          'No foods found. Try another search.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (_, index) {
        final item = foods[index];
        final category = _categoryForFood(item);
        return _FoodCard(
          item: item,
          isFavorite: _favoriteIds.contains(item.id),
          onFavorite: () => _toggleFavorite(item),
          onAdd: (serving) {
            _logFood(item, serving);
            _addToMealBuilder(item, serving);
          },
          category: category,
        );
      },
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TabSwitcher({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['Search', 'Recent & Favorites', 'History'];
    return SegmentedButton<int>(
      segments: List.generate(
        tabs.length,
        (i) => ButtonSegment(value: i, label: Text(tabs[i])),
      ),
      selected: {index},
      onSelectionChanged: (v) => onChanged(v.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white10
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.all(Colors.white),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> recentSearches;
  final void Function(String) onRecentTap;
  final VoidCallback onOpenManual;
  final ValueChanged<String> onCategoryChanged;
  final String selectedCategory;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.recentSearches,
    required this.onRecentTap,
    required this.onOpenManual,
    required this.onCategoryChanged,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      'Proteins',
      'Carbs',
      'Fruits',
      'Fats',
      'Drinks',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Search foods, e.g. "oats"',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: onOpenManual,
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'Manual entry',
            ),
          ),
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in categories)
              ChoiceChip(
                label: Text(cat),
                selected: selectedCategory == cat,
                onSelected: (_) => onCategoryChanged(cat),
              ),
          ],
        ),
        if (recentSearches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: recentSearches
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    avatar: const Icon(Icons.history, size: 16),
                    onPressed: () => onRecentTap(s),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _FoodCard extends StatefulWidget {
  final FoodItem item;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final void Function(double) onAdd;
  final String category;

  const _FoodCard({
    required this.item,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
    required this.category,
  });

  @override
  State<_FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<_FoodCard> {
  double _serving = 1;
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.white),
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
                          item.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${item.calories.toStringAsFixed(0)} kcal / ${item.servingSize.toStringAsFixed(0)}${item.unit}',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _pill('${item.protein}g P', Colors.blueAccent),
                      _pill('${item.carbs}g C', Colors.orangeAccent),
                      _pill('${item.fat}g F', Colors.amber),
                      _pill(widget.category, Colors.white30),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<double>(
                          value: _serving,
                          decoration:
                              const InputDecoration(labelText: 'Servings'),
                          items: const [
                            DropdownMenuItem(
                              value: 0.5,
                              child: Text('0.5x'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('1x'),
                            ),
                            DropdownMenuItem(
                              value: 1.5,
                              child: Text('1.5x'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('2x'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _serving = v ?? 1),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: widget.onFavorite,
                        icon: Icon(
                          widget.isFavorite
                              ? Icons.star
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          widget.onAdd(_serving);
                          setState(() => _added = true);
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (mounted) setState(() => _added = false);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _added ? Colors.green : Colors.blueAccent,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _added
                              ? const Icon(Icons.check, key: ValueKey('c'))
                              : const Text('Add', key: ValueKey('a')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Chip(
      backgroundColor: color.withOpacity(0.16),
      labelStyle: TextStyle(color: color),
      label: Text(text),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RecentFavorites extends StatelessWidget {
  final List<FoodItem> recentFoods;
  final Set<String> favoriteIds;
  final void Function(FoodItem, double) onAdd;
  final void Function(FoodItem) onFavoriteToggle;

  const _RecentFavorites({
    required this.recentFoods,
    required this.favoriteIds,
    required this.onAdd,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle('Recent'),
        if (recentFoods.isEmpty)
          _empty('No recent foods yet.')
        else
          ...recentFoods.map(
            (f) => _QuickRow(
              item: f,
              isFavorite: favoriteIds.contains(f.id),
              onFavorite: () => onFavoriteToggle(f),
              onAdd: () => onAdd(f, 1),
            ),
          ),
        const SizedBox(height: 12),
        _sectionTitle('Favorites'),
        if (favoriteIds.isEmpty)
          _empty('Tap star to pin favorites.')
        else
          ...favoriteIds.map((id) {
            final matching =
                recentFoods.where((f) => f.id == id).toList();
            if (matching.isEmpty) {
              return const SizedBox.shrink();
            }
            final item = matching.first;
            return _QuickRow(
              item: item,
              isFavorite: true,
              onFavorite: () => onFavoriteToggle(item),
              onAdd: () => onAdd(item, 1),
            );
          }),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70),
        ),
      );
}

class _QuickRow extends StatelessWidget {
  final FoodItem item;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAdd;

  const _QuickRow({
    required this.item,
    required this.isFavorite,
    required this.onFavorite,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.04),
      child: ListTile(
        title: Text(item.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${item.calories.toStringAsFixed(0)} kcal',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealBuilder extends StatelessWidget {
  final List<_MealDraftItem> items;
  final void Function(int, int) onReorder;
  final void Function(int) onRemove;
  final void Function(String) onNameChanged;
  final String mealName;
  final (double, double, double, double) totals;
  final VoidCallback onLogMeal;

  const _MealBuilder({
    required this.items,
    required this.onReorder,
    required this.onRemove,
    required this.onNameChanged,
    required this.mealName,
    required this.totals,
    required this.onLogMeal,
  });

  @override
  Widget build(BuildContext context) {
    final (cal, p, c, f) = totals;
    return Card(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lunch_dining, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Meal name',
                    ),
                    controller: TextEditingController(text: mealName),
                    onChanged: onNameChanged,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: items.isEmpty ? null : onLogMeal,
                  icon: const Icon(Icons.check),
                  label: const Text('Log meal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat('$cal kcal'),
                _miniStat('${p.toStringAsFixed(1)}g P'),
                _miniStat('${c.toStringAsFixed(1)}g C'),
                _miniStat('${f.toStringAsFixed(1)}g F'),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text(
                'Add foods to build a meal.',
                style: TextStyle(color: Colors.white70),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                onReorder: onReorder,
                itemBuilder: (_, index) {
                  final draft = items[index];
                  return ListTile(
                    key: ValueKey(draft.item.id + index.toString()),
                    title: Text(
                      draft.item.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${draft.item.calories * draft.servings} kcal • ${draft.servings}x',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      onPressed: () => onRemove(index),
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String text) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(text),
          backgroundColor: Colors.white12,
          labelStyle: const TextStyle(color: Colors.white),
        ),
      );
}

class _ManualEntryForm extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController carbCtrl;
  final TextEditingController fatCtrl;
  final void Function(FoodItem custom) onSave;

  const _ManualEntryForm({
    required this.nameCtrl,
    required this.caloriesCtrl,
    required this.proteinCtrl,
    required this.carbCtrl,
    required this.fatCtrl,
    required this.onSave,
  });

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  bool _favorite = false;
  String? _warning;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Manual entry',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            const Spacer(),
            IconButton(
              icon: Icon(
                _favorite ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => setState(() => _favorite = !_favorite),
            ),
          ],
        ),
        TextField(
          controller: widget.nameCtrl,
          decoration: const InputDecoration(labelText: 'Food name'),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.caloriesCtrl,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.proteinCtrl,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.carbCtrl,
                decoration: const InputDecoration(labelText: 'Carbs (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.fatCtrl,
                decoration: const InputDecoration(labelText: 'Fats (g)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              ),
            ),
          ],
        ),
        if (_warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _warning!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _validateAndSave,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save'),
          ),
        ),
      ],
    );
  }

  void _validateAndSave() {
    final name = widget.nameCtrl.text.trim();
    final calories = double.tryParse(widget.caloriesCtrl.text) ?? 0;
    final protein = double.tryParse(widget.proteinCtrl.text) ?? 0;
    final carbs = double.tryParse(widget.carbCtrl.text) ?? 0;
    final fats = double.tryParse(widget.fatCtrl.text) ?? 0;

    if (name.isEmpty || calories <= 0) {
      setState(() => _warning = 'Enter name and calories.');
      return;
    }
    final expected = protein * 4 + carbs * 4 + fats * 9;
    final diff = (expected - calories).abs();
    if (diff > calories * 0.2) {
      setState(() => _warning =
          'Calories differ from macros by ${diff.toStringAsFixed(0)}. Please check.');
      return;
    }
    final custom = FoodItem(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      servingSize: 1,
      unit: 'serving',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fats,
    );
    widget.onSave(custom);
  }
}

class _HistoryView extends StatelessWidget {
  final DateTime selectedDay;
  final void Function(DateTime) onDaySelected;
  final Map<DateTime, List<_LoggedMeal>> history;
  final Future<void> Function(_LoggedMeal) onCopyToToday;

  const _HistoryView({
    required this.selectedDay,
    required this.onDaySelected,
    required this.history,
    required this.onCopyToToday,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      14,
      (i) => DateTime.now().subtract(Duration(days: i)),
    );
    final meals = history[selectedDay] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final day = days[index];
              final isSelected = _isSameDay(day, selectedDay);
              return GestureDetector(
                onTap: () => onDaySelected(day),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.blueAccent : Colors.white12,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdayLabel(day),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        day.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(Icons.local_fire_department, color: Colors.orangeAccent),
            SizedBox(width: 6),
            Text('Streak: 5 days logged in a row!',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        const SizedBox(height: 8),
        if (meals.isEmpty)
          const Text('No meals logged for this day.',
              style: TextStyle(color: Colors.white70))
        else
          ...meals.map(
            (m) => Card(
              color: Colors.white.withOpacity(0.05),
              child: ListTile(
                title: Text(
                  m.item.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${m.item.calories * m.servings} kcal',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: TextButton(
                  onPressed: () => onCopyToToday(m),
                  child: const Text('Copy to today'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLabel(DateTime day) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return labels[day.weekday % 7];
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.04),
      child: const ListTile(
        leading: CircleAvatar(backgroundColor: Colors.white12),
        title: SizedBox(height: 12, child: ColoredBox(color: Colors.white12)),
        subtitle: SizedBox(height: 12, child: ColoredBox(color: Colors.white10)),
      ),
    );
  }
}

class _MealDraftItem {
  final FoodItem item;
  final double servings;

  _MealDraftItem({
    required this.item,
    required this.servings,
  });
}

class _LoggedMeal {
  final FoodItem item;
  final double servings;

  _LoggedMeal({required this.item, required this.servings});
}

String _categoryForFood(FoodItem item) {
  if (item.protein >= item.carbs && item.protein >= item.fat) {
    return 'Proteins';
  }
  if (item.carbs >= item.protein && item.carbs >= item.fat) {
    if (item.name.toLowerCase().contains('fruit')) return 'Fruits';
    return 'Carbs';
  }
  if (item.fat >= item.protein && item.fat >= item.carbs) return 'Fats';
  return 'Drinks';
}
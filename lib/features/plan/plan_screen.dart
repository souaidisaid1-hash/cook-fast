import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/recipe.dart';
import '../../shared/models/shopping_item.dart';
import '../../shared/services/gemini_service.dart';
import '../../shared/services/meal_db_service.dart';
import '../../shared/services/notification_service.dart';

// ─── Local state ──────────────────────────────────────────────────────────────

class _PlanState {
  final bool isGenerating;
  final int genProgress;

  const _PlanState({this.isGenerating = false, this.genProgress = 0});

  _PlanState copyWith({bool? isGenerating, int? genProgress}) => _PlanState(
        isGenerating: isGenerating ?? this.isGenerating,
        genProgress: genProgress ?? this.genProgress,
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _PlanState _state = const _PlanState();

  static const _days = WeekPlanNotifier.days;
  static const _slots = WeekPlanNotifier.slots;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday; // 1=Lun … 7=Dim
    final initial = (today - 1).clamp(0, 6);
    _tabController = TabController(length: _days.length, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Generate full week ────────────────────────────────────────────────────

  Future<void> _generateWeek() async {
    setState(() => _state = _PlanState(isGenerating: true, genProgress: 5));
    final profile = ref.read(userProfileProvider);
    final planNotifier = ref.read(weekPlanProvider.notifier);

    try {
      final names = await GeminiService.generateWeekPlan(
        profile,
        onProgress: (p) {
          if (mounted) setState(() => _state = _state.copyWith(genProgress: p));
        },
      );

      if (names == null) {
        // Fallback : plan aléatoire depuis MealDB
        if (mounted) setState(() => _state = _state.copyWith(genProgress: 50));
        await _generateFallbackPlan(planNotifier);
        return;
      }

      if (mounted) setState(() => _state = _state.copyWith(genProgress: 75));

      // Resolve recipe names → Recipe objects
      final newPlan = <String, Map<String, Recipe?>>{};
      for (final day in _days) {
        newPlan[day] = {};
        final dayMap = names[day];
        if (dayMap is Map) {
          final slotFutures = <String, Future<Recipe?>>{};
          for (final slot in _slots) {
            final name = dayMap[slot]?.toString() ?? '';
            if (name.isNotEmpty) {
              slotFutures[slot] =
                  MealDbService.search(name).then((r) => r.firstOrNull);
            }
          }
          for (final slot in _slots) {
            newPlan[day]![slot] = slotFutures.containsKey(slot)
                ? await slotFutures[slot]
                : null;
          }
        } else {
          for (final slot in _slots) {
            newPlan[day]![slot] = null;
          }
        }
      }

      planNotifier.setPlan(newPlan);
      if (mounted) {
        setState(() => _state = const _PlanState());
        _showSnack('Plan IA généré ✨');
      }
    } catch (e) {
      if (mounted) {
        await _generateFallbackPlan(ref.read(weekPlanProvider.notifier));
      }
    }
  }

  Future<void> _generateFallbackPlan(WeekPlanNotifier planNotifier) async {
    // 21 recettes aléatoires depuis MealDB (7 jours × 3 repas)
    final recipes = await Future.wait(
      List.generate(21, (_) => MealDbService.random()),
    );
    final queue = recipes.whereType<Recipe>().toList();

    final newPlan = <String, Map<String, Recipe?>>{};
    var idx = 0;
    for (final day in _days) {
      newPlan[day] = {};
      for (final slot in _slots) {
        newPlan[day]![slot] = idx < queue.length ? queue[idx++] : null;
      }
    }

    planNotifier.setPlan(newPlan);
    if (mounted) {
      setState(() => _state = const _PlanState());
      _showSnack('Plan généré (mode aléatoire) 🎲');
    }
  }

  // ── Export to shopping ────────────────────────────────────────────────────

  void _exportToShopping() {
    final plan = ref.read(weekPlanProvider);
    final shoppingNotifier = ref.read(shoppingProvider.notifier);
    final items = <ShoppingItem>[];

    for (final daySlots in plan.values) {
      for (final entry in daySlots.entries) {
        final recipe = entry.value;
        if (recipe == null) continue;
        for (var i = 0; i < recipe.ingredients.length; i++) {
          final name = recipe.ingredients[i];
          final measure = recipe.measures.elementAtOrNull(i) ?? '';
          items.add(ShoppingItem(
            name: name,
            measure: measure,
            category: ShoppingItem.categorizeIngredient(name),
            recipeTitle: recipe.title,
          ));
        }
      }
    }

    if (items.isEmpty) {
      _showSnack('Aucune recette planifiée.');
      return;
    }

    shoppingNotifier.addAll(items);
    _showSnack('${items.length} articles ajoutés à la liste de courses 🛒');
  }

  Future<void> _scheduleReminders() async {
    final notifSettings = ref.read(notifSettingsProvider);
    if (!notifSettings.mealReminders) {
      _showSnack('Rappels repas désactivés dans les paramètres 🔕');
      return;
    }
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) {
      _showSnack('Permission notifications refusée');
      return;
    }
    final plan = ref.read(weekPlanProvider);
    final rawPlan = plan.map((day, slots) =>
        MapEntry(day, slots.map((slot, recipe) =>
            MapEntry(slot, recipe != null ? {'title': recipe.title} : null))));
    final count = await NotificationService.scheduleMealReminders(rawPlan);
    if (mounted) {
      _showSnack(count > 0
          ? '$count rappels repas programmés 🔔'
          : 'Aucun repas à venir cette semaine');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF323232),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final plan = ref.watch(weekPlanProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    final totalMeals = plan.values
        .expand((s) => s.values)
        .where((r) => r != null)
        .length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4, height: 22,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.yellow],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Plan de la semaine',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            totalMeals == 0 ? 'Aucun repas planifié' : '$totalMeals repas planifiés',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rappels repas
                  if (totalMeals > 0)
                    _iconBtn(
                      icon: Icons.notifications_outlined,
                      color: AppColors.yellow,
                      onTap: _scheduleReminders,
                      isDark: isDark,
                    ),
                  const SizedBox(width: 8),
                  // Export courses
                  if (totalMeals > 0)
                    _iconBtn(
                      icon: Icons.shopping_cart_outlined,
                      color: AppColors.green,
                      onTap: _exportToShopping,
                      isDark: isDark,
                    ),
                  const SizedBox(width: 8),
                  // Clear all
                  if (totalMeals > 0)
                    _iconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => _confirmClearAll(context),
                      isDark: isDark,
                    ),
                  const SizedBox(width: 8),
                  // Generate AI
                  GestureDetector(
                    onTap: _state.isGenerating ? null : _generateWeek,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: _state.isGenerating ? null : const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                        color: _state.isGenerating ? AppColors.primary : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _state.isGenerating ? null : [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          const Text('IA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Loading overlay ───────────────────────────────────────────────
            if (_state.isGenerating)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                        const SizedBox(width: 10),
                        Text('Génération du plan en cours…', style: TextStyle(fontSize: 13, color: subColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _state.genProgress / 100,
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ── Day tabs ──────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: subColor,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              dividerColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: _days.map((d) {
                final count = plan[d]?.values.where((r) => r != null).length ?? 0;
                return Tab(
                  child: Row(
                    children: [
                      Text(d.substring(0, 3)),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Center(child: Text('$count', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),

            // ── Day pages ─────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _days.map((day) {
                  final dayPlan = plan[day] ?? {};
                  return _DayView(
                    day: day,
                    dayPlan: dayPlan,
                    isDark: isDark,
                    textColor: textColor,
                    subColor: subColor,
                    cardColor: cardColor,
                    onSetMeal: (slot, recipe) =>
                        ref.read(weekPlanProvider.notifier).setMeal(day, slot, recipe),
                    onClearMeal: (slot) =>
                        ref.read(weekPlanProvider.notifier).setMeal(day, slot, null),
                    onClearDay: () => ref.read(weekPlanProvider.notifier).clearDay(day),
                    onSuggestSlot: (slot) => _suggestSlot(day, slot),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _suggestSlot(String day, String slot) async {
    final profile = ref.read(userProfileProvider);
    final name = await GeminiService.suggestMeal(profile, slot);
    if (name == null || !mounted) return;
    final results = await MealDbService.search(name);
    final recipe = results.firstOrNull;
    if (recipe != null) {
      ref.read(weekPlanProvider.notifier).setMeal(day, slot, recipe);
      _showSnack('${recipe.title} suggéré ✨');
    } else {
      _showSnack('Aucune recette trouvée pour "$name"');
    }
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Vider le plan ?'),
        content: const Text('Tous les repas de la semaine seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              ref.read(weekPlanProvider.notifier).clear();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap, required bool isDark}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      );
}

// ─── Day View ─────────────────────────────────────────────────────────────────

class _DayView extends StatelessWidget {
  final String day;
  final Map<String, Recipe?> dayPlan;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  final void Function(String slot, Recipe recipe) onSetMeal;
  final void Function(String slot) onClearMeal;
  final VoidCallback onClearDay;
  final void Function(String slot) onSuggestSlot;

  const _DayView({
    required this.day,
    required this.dayPlan,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.onSetMeal,
    required this.onClearMeal,
    required this.onClearDay,
    required this.onSuggestSlot,
  });

  static const _slots = WeekPlanNotifier.slots;
  static const _slotEmojis = {'Petit-déj': '☀️', 'Déjeuner': '🌤️', 'Dîner': '🌙'};

  @override
  Widget build(BuildContext context) {
    final filledCount = dayPlan.values.where((r) => r != null).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Day header with clear button
        if (filledCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onClearDay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                        const SizedBox(width: 5),
                        const Text('Vider la journée', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        ..._slots.map((slot) => _SlotCard(
              slot: slot,
              emoji: _slotEmojis[slot] ?? '🍽️',
              recipe: dayPlan[slot],
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
              cardColor: cardColor,
              onSetMeal: (r) => onSetMeal(slot, r),
              onClear: () => onClearMeal(slot),
              onSuggest: () => onSuggestSlot(slot),
            )),
      ],
    );
  }
}

// ─── Slot Card ────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  final String slot;
  final String emoji;
  final Recipe? recipe;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  final void Function(Recipe) onSetMeal;
  final VoidCallback onClear;
  final VoidCallback onSuggest;

  const _SlotCard({
    required this.slot,
    required this.emoji,
    required this.recipe,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.onSetMeal,
    required this.onClear,
    required this.onSuggest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: recipe == null ? _emptySlot(context) : _filledSlot(context),
    );
  }

  Widget _emptySlot(BuildContext context) => InkWell(
        onTap: () => _openSearch(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(slot, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text('Appuie pour choisir', style: TextStyle(fontSize: 12, color: subColor)),
                  ],
                ),
              ),
              // Suggest AI
              GestureDetector(
                onTap: onSuggest,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
            ],
          ),
        ),
      );

  Widget _filledSlot(BuildContext context) => InkWell(
        onTap: () => context.push('/recipe/${recipe!.id}', extra: recipe),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: recipe!.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: recipe!.imageUrl!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _imgPlaceholder(),
                      errorWidget: (context, url, err) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(slot,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe!.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe!.category != null) ...[
                      const SizedBox(height: 4),
                      Text(recipe!.category!, style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                  onPressed: () => _openSearch(context),
                  tooltip: 'Changer',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                  onPressed: onClear,
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ],
        ),
      );

  Widget _imgPlaceholder() => Container(
        width: 90,
        height: 90,
        color: AppColors.darkBorder,
        child: const Center(child: Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 28)),
      );

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchModal(
        slot: slot,
        isDark: isDark,
        textColor: textColor,
        subColor: subColor,
        cardColor: cardColor,
        onSelect: onSetMeal,
      ),
    );
  }
}

// ─── Search Modal ─────────────────────────────────────────────────────────────

class _SearchModal extends StatefulWidget {
  final String slot;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  final void Function(Recipe) onSelect;

  const _SearchModal({
    required this.slot,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.onSelect,
  });

  @override
  State<_SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<_SearchModal> {
  final _ctrl = TextEditingController();
  List<Recipe> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final results = await MealDbService.search(query.trim());
    if (mounted) setState(() {_results = results; _loading = false;});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = widget.textColor;
    final subColor = widget.subColor;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Choisir pour ${widget.slot}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
          ),
          const SizedBox(height: 14),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: TextStyle(color: textColor),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Rechercher une recette…',
                hintStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Results
          Expanded(
            child: _results.isEmpty && !_loading
                ? Center(
                    child: Text(
                      _ctrl.text.isEmpty ? 'Tape un nom de recette' : 'Aucun résultat',
                      style: TextStyle(color: subColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: r.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: r.imageUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: AppColors.darkBorder,
                                  child: const Icon(Icons.restaurant_rounded, color: AppColors.primary),
                                ),
                        ),
                        title: Text(r.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                        subtitle: r.category != null
                            ? Text(r.category!, style: TextStyle(fontSize: 12, color: subColor))
                            : null,
                        onTap: () {
                          widget.onSelect(r);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

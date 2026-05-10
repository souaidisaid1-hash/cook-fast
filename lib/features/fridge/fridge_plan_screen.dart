import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/models/shopping_item.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/gemini_service.dart';
import '../../shared/services/meal_db_service.dart';

class FridgePlanScreen extends ConsumerStatefulWidget {
  const FridgePlanScreen({super.key});

  @override
  ConsumerState<FridgePlanScreen> createState() => _FridgePlanScreenState();
}

class _FridgePlanScreenState extends ConsumerState<FridgePlanScreen> {
  static const _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  static const _slots = ['Petit-déj', 'Déjeuner', 'Dîner'];

  int _progress = 0;
  String _statusMsg = 'Analyse du frigo…';
  Map<String, Map<String, Recipe?>>? _plan;
  List<String> _missing = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final fridge = ref.read(fridgeProvider);
    final profile = ref.read(userProfileProvider);

    setState(() {
      _progress = 0;
      _statusMsg = 'Génération du plan IA…';
      _plan = null;
      _error = null;
    });

    // Step 1: Gemini generates recipe names
    final names = await GeminiService.generateWeekPlanFromFridge(
      fridge,
      profile,
      onProgress: (p) {
        if (mounted) setState(() => _progress = (p * 0.5).round());
      },
    );

    if (names == null) {
      if (mounted) setState(() => _error = 'Impossible de générer le plan. Réessaie.');
      return;
    }

    if (mounted) setState(() { _progress = 50; _statusMsg = 'Recherche des recettes…'; });

    // Step 2: Resolve names → Recipe objects via MealDB
    final newPlan = <String, Map<String, Recipe?>>{};
    final allIngredients = <String>{};
    int resolved = 0;
    final total = _days.length * _slots.length;

    for (final day in _days) {
      newPlan[day] = {};
      final dayMap = names[day];
      for (final slot in _slots) {
        final name = (dayMap is Map ? dayMap[slot] : null)?.toString() ?? '';
        Recipe? recipe;
        if (name.isNotEmpty) {
          final results = await MealDbService.search(name);
          recipe = results.firstOrNull;
          if (recipe != null) {
            allIngredients.addAll(recipe.ingredients.map((i) => i.toLowerCase()));
          }
        }
        newPlan[day]![slot] = recipe;
        resolved++;
        if (mounted) {
          setState(() => _progress = 50 + (resolved / total * 45).round());
        }
      }
    }

    // Step 3: Compute missing ingredients
    final fridgeLower = ref.read(fridgeProvider).map((i) => i.toLowerCase()).toSet();
    final missing = allIngredients
        .where((ing) => ing.isNotEmpty && !fridgeLower.any((f) => ing.contains(f) || f.contains(ing)))
        .take(20)
        .toList()
      ..sort();

    if (mounted) {
      setState(() {
        _plan = newPlan;
        _missing = missing;
        _progress = 100;
        _statusMsg = 'Plan prêt !';
      });
    }
  }

  void _applyPlan() {
    if (_plan == null) return;
    ref.read(weekPlanProvider.notifier).setPlan(_plan!);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Plan appliqué à la semaine ✅'),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    context.pop();
    context.go('/plan');
  }

  void _addMissingToShopping() {
    final notifier = ref.read(shoppingProvider.notifier);
    for (final ing in _missing) {
      notifier.add(ing, measure: '');
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_missing.length} ingrédients ajoutés aux courses 🛒'),
      backgroundColor: const Color(0xFF323232),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    setState(() => _missing = []);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Plan IA depuis frigo 🧊',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: textColor)),
        elevation: 0,
      ),
      body: _error != null
          ? _buildError(textColor, subColor)
          : _plan == null
              ? _buildLoading(textColor, subColor, isDark)
              : _buildResult(cardColor, textColor, subColor, isDark, navBar),
    );
  }

  Widget _buildLoading(Color textColor, Color subColor, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 24),
            Text(_statusMsg,
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Text('$_progress%', style: TextStyle(color: subColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Color textColor, Color subColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(color: textColor, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Color cardColor, Color textColor, Color subColor, bool isDark, double navBar) {
    final plan = _plan!;
    final filledCount = plan.values
        .expand((s) => s.values)
        .where((r) => r != null)
        .length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1a3a1a), Color(0xFF0d200d)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$filledCount repas générés',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                'Basé sur ${ref.read(fridgeProvider).length} ingrédients du frigo',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Day cards
                ..._days.map((day) {
                  final slots = plan[day] ?? {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                          child: Text(day,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        ..._slots.map((slot) {
                          final recipe = slots[slot];
                          final emoji = slot == 'Petit-déj'
                              ? '🌅'
                              : slot == 'Déjeuner'
                                  ? '☀️'
                                  : '🌙';
                          return InkWell(
                            onTap: recipe != null
                                ? () => context.push('/recipe/${recipe.id}', extra: recipe)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
                              child: Row(
                                children: [
                                  Text(emoji,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Text('$slot · ',
                                      style: TextStyle(
                                          color: subColor, fontSize: 12)),
                                  Expanded(
                                    child: Text(
                                      recipe?.title ?? '—',
                                      style: TextStyle(
                                          color: recipe != null
                                              ? textColor
                                              : subColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (recipe != null)
                                    const Icon(Icons.chevron_right,
                                        size: 16, color: AppColors.textDarkSecondary),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    ),
                  );
                }),

                // Missing ingredients
                if (_missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('🛒 Ingrédients manquants',
                          style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: _addMissingToShopping,
                        child: const Text('Tout ajouter',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _missing.map((ing) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(ing,
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Bottom CTAs
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + navBar),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBg : AppColors.lightBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Regénérer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDarkSecondary,
                  side: const BorderSide(color: AppColors.darkBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyPlan,
                  icon: const Text('📅', style: TextStyle(fontSize: 16)),
                  label: const Text('Appliquer au plan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

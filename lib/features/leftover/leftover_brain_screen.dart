import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/gemini_service.dart';

class LeftoverBrainScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const LeftoverBrainScreen({super.key, required this.recipe});

  @override
  ConsumerState<LeftoverBrainScreen> createState() => _LeftoverBrainScreenState();
}

class _LeftoverBrainScreenState extends ConsumerState<LeftoverBrainScreen> {
  late List<bool> _selected; // true = ingrédient restant
  bool _loading = false;
  bool _analyzed = false;
  bool _usedFallback = false;
  List<_Reinvention> _reinventions = [];

  @override
  void initState() {
    super.initState();
    // Par défaut : rien ne reste (tout a été utilisé)
    _selected = List.filled(widget.recipe.ingredients.length, false);
  }

  int get _leftoverCount => _selected.where((s) => s).length;
  int get _totalCount => widget.recipe.ingredients.length;

  int get _wasteScore {
    if (_totalCount == 0) return 100;
    return ((_totalCount - _leftoverCount) / _totalCount * 100).round();
  }

  Color get _scoreColor {
    if (_wasteScore >= 80) return AppColors.green;
    if (_wasteScore >= 60) return AppColors.yellow;
    if (_wasteScore >= 40) return const Color(0xFFFF9F43);
    return Colors.red;
  }

  String get _scoreLabel {
    if (_wasteScore >= 80) return 'Excellent ! Zéro gaspillage 🌱';
    if (_wasteScore >= 60) return 'Bien joué ! Peu de gaspillage 👍';
    if (_wasteScore >= 40) return 'Passable, réinventez les restes 🧠';
    return 'Beaucoup de restes — Leftover Brain à l\'aide ! 🔥';
  }

  Future<void> _analyze() async {
    final leftovers = [
      for (int i = 0; i < widget.recipe.ingredients.length; i++)
        if (_selected[i]) widget.recipe.ingredients[i],
    ];
    final ingredients =
        leftovers.isEmpty ? widget.recipe.ingredients.take(5).toList() : leftovers;

    setState(() {
      _loading = true;
      _analyzed = false;
      _reinventions = [];
    });

    // XP ecology uniquement au premier analyze
    ref.read(skillTreeProvider.notifier).addXp('ecology', 15);

    final results = await GeminiService.suggestLeftoverReinventions(
      widget.recipe.title,
      ingredients,
    );

    List<_Reinvention> parsed;
    if (results.isEmpty) {
      parsed = _fallback(ingredients);
      if (mounted) setState(() => _usedFallback = true);
    } else {
      if (mounted) setState(() => _usedFallback = false);
      parsed = results.map((s) {
        final idx = s.indexOf(' — ');
        if (idx == -1) return _Reinvention(title: s, description: '');
        return _Reinvention(
          title: s.substring(0, idx),
          description: s.substring(idx + 3),
        );
      }).toList();
    }

    setState(() {
      _loading = false;
      _analyzed = true;
      _reinventions = parsed;
    });
  }

  List<_Reinvention> _fallback(List<String> ingredients) {
    final ing = ingredients.take(3).join(', ');
    final two = ingredients.take(2).join(' et ');
    return [
      _Reinvention(
        title: 'Poêlée de restes',
        description: 'Faites revenir $ing à la poêle avec un filet d\'huile, ail et épices — prêt en 10 min.',
      ),
      _Reinvention(
        title: 'Soupe express',
        description: 'Mixez $ing avec du bouillon chaud pour une soupe rapide et réconfortante.',
      ),
      _Reinvention(
        title: 'Wrap ou sandwich',
        description: 'Garnissez une tortilla ou du pain avec $two pour un repas rapide sans cuisson.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.green, Color(0xFF27AE60)]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Leftover Brain 🧠', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text("Zéro gaspillage avec l'IA", style: TextStyle(color: subColor, fontSize: 11)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecipeBanner(isDark, textColor),
              const SizedBox(height: 24),
              _buildWasteScore(isDark),
              const SizedBox(height: 24),
              _buildIngredientSelector(isDark, textColor, subColor),
              const SizedBox(height: 24),
              _buildCTA(),
              if (_analyzed && _reinventions.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildResults(isDark, textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeBanner(bool isDark, Color textColor) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recette cuisinée', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    widget.recipe.title,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildWasteScore(bool isDark) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _scoreColor.withValues(alpha: isDark ? 0.1 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _wasteScore / 100,
                    strokeWidth: 6,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    color: _scoreColor,
                  ),
                  Text(
                    '$_wasteScore',
                    style: TextStyle(
                      color: _scoreColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waste Score', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _scoreLabel,
                    style: TextStyle(color: _scoreColor, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (_leftoverCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$_leftoverCount ingrédient${_leftoverCount > 1 ? 's' : ''} restant${_leftoverCount > 1 ? 's' : ''}',
                      style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildIngredientSelector(bool isDark, Color textColor, Color subColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quels ingrédients vous restent ?',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Sélectionnez les ingrédients non utilisés.',
            style: TextStyle(color: subColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < widget.recipe.ingredients.length; i++)
                _IngredientChip(
                  label: widget.recipe.ingredients[i],
                  measure: widget.recipe.measures.elementAtOrNull(i),
                  selected: _selected[i],
                  isDark: isDark,
                  onToggle: (v) => setState(() => _selected[i] = v),
                ),
            ],
          ),
        ],
      );

  Widget _buildCTA() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _analyze,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('✨', style: TextStyle(fontSize: 16)),
          label: Text(_loading ? 'Analyse en cours...' : 'Réinventer les restes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _buildResults(bool isDark, Color textColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Idées de réinvention 💡',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (_usedFallback) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.yellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 15, color: AppColors.yellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'IA indisponible — suggestions locales',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (int i = 0; i < _reinventions.length; i++) ...[
            _ReinventionCard(index: i + 1, reinvention: _reinventions[i], isDark: isDark),
            if (i < _reinventions.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _IngredientChip extends StatelessWidget {
  final String label;
  final String? measure;
  final bool selected;
  final bool isDark;
  final ValueChanged<bool> onToggle;

  const _IngredientChip({
    required this.label,
    this.measure,
    required this.selected,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.withValues(alpha: 0.15) : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.orange : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [] : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.remove_circle_outline, size: 14, color: Colors.orange),
              ),
            Flexible(
              child: Text(
                measure != null && measure!.isNotEmpty ? '$measure $label' : label,
                style: TextStyle(
                  color: selected ? Colors.orange : (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReinventionCard extends StatelessWidget {
  final int index;
  final _Reinvention reinvention;
  final bool isDark;

  const _ReinventionCard({required this.index, required this.reinvention, required this.isDark});

  static const _emojis = ['🥘', '🍜', '🥗'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _emojis.elementAtOrNull(index - 1) ?? '🍴',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reinvention.title,
                  style: TextStyle(
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reinvention.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reinvention.description,
                    style: TextStyle(
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reinvention {
  final String title;
  final String description;
  const _Reinvention({required this.title, required this.description});
}

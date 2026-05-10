import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final journal = ref.watch(journalProvider);
    final xp = ref.watch(skillTreeProvider);
    final plan = ref.watch(weekPlanProvider);
    final profile = ref.watch(userProfileProvider);
    final favorites = ref.watch(favoritesProvider);

    // ── Computed stats ────────────────────────────────────────────────────────
    final totalXp = xp.values.fold(0, (a, b) => a + b);
    final level = _level(totalXp);

    // Last 7 days activity
    final now = DateTime.now();
    final days7 = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
    final perDay = days7.map((d) => journal
        .where((e) =>
            e.cookedAt.year == d.year &&
            e.cookedAt.month == d.month &&
            e.cookedAt.day == d.day)
        .length).toList();

    // Category breakdown from journal
    final catCount = <String, int>{};
    for (final e in journal) {
      final cat = e.category ?? 'Autre';
      catCount[cat] = (catCount[cat] ?? 0) + 1;
    }
    final topCats = (catCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .toList();

    // Average rating
    final rated = journal.where((e) => e.rating > 0).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((e) => e.rating).reduce((a, b) => a + b) / rated.length;

    // Plan fill rate
    final totalSlots = plan.values.expand((s) => s.values).length;
    final filledSlots =
        plan.values.expand((s) => s.values).where((r) => r != null).length;
    final planRate = totalSlots == 0 ? 0.0 : filledSlots / totalSlots;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Statistiques 📊',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18, color: textColor)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── XP Hero card ───────────────────────────────────────────────────
            _heroCard(totalXp, level, journal.length, favorites.length),

            const SizedBox(height: 16),

            // ── Quick stats row ────────────────────────────────────────────────
            Row(
              children: [
                _quickStat(cardColor, textColor, subColor, '📔',
                    '${journal.length}', 'Recettes\ncuisinées'),
                const SizedBox(width: 10),
                _quickStat(cardColor, textColor, subColor, '⭐',
                    avgRating == 0 ? '—' : avgRating.toStringAsFixed(1),
                    'Note\nmoyenne'),
                const SizedBox(width: 10),
                _quickStat(cardColor, textColor, subColor, '❤️',
                    '${favorites.length}', 'Recettes\nfavorites'),
              ],
            ),

            const SizedBox(height: 20),

            // ── Activity chart ─────────────────────────────────────────────────
            _sectionTitle(textColor, 'Activité des 7 derniers jours'),
            const SizedBox(height: 12),
            _card(cardColor,
                child: SizedBox(
                  height: 140,
                  child: perDay.every((v) => v == 0)
                      ? Center(
                          child: Text('Aucune recette cuisinée cette semaine',
                              style: TextStyle(color: subColor, fontSize: 13)))
                      : BarChart(
                          BarChartData(
                            maxY: (perDay.reduce((a, b) => a > b ? a : b) + 1)
                                .toDouble(),
                            barGroups: List.generate(
                              7,
                              (i) => BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                  toY: perDay[i].toDouble(),
                                  color: perDay[i] > 0
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                                  width: 18,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ]),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final d = days7[v.toInt()];
                                    final labels = [
                                      'Lu', 'Ma', 'Me', 'Je',
                                      'Ve', 'Sa', 'Di'
                                    ];
                                    return Text(
                                      labels[d.weekday - 1],
                                      style: TextStyle(
                                          color: subColor, fontSize: 11),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                )),

            const SizedBox(height: 20),

            // ── XP par branche ─────────────────────────────────────────────────
            _sectionTitle(textColor, 'XP par branche'),
            const SizedBox(height: 12),
            _card(cardColor,
                child: Column(
                  children: _branches.map((b) {
                    final branchXp = xp[b.id] ?? 0;
                    final maxXp = xp.values.isEmpty
                        ? 1
                        : xp.values.reduce((a, v) => a > v ? a : v);
                    final ratio =
                        maxXp == 0 ? 0.0 : branchXp / maxXp.toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(b.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(b.label,
                                        style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text('$branchXp XP',
                                        style: TextStyle(
                                            color: subColor, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    backgroundColor: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    valueColor:
                                        AlwaysStoppedAnimation(b.color),
                                    minHeight: 7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )),

            const SizedBox(height: 20),

            // ── Top catégories ─────────────────────────────────────────────────
            if (topCats.isNotEmpty) ...[
              _sectionTitle(textColor, 'Catégories cuisinées'),
              const SizedBox(height: 12),
              _card(cardColor,
                  child: Column(
                    children: topCats.asMap().entries.map((e) {
                      final idx = e.key;
                      final cat = e.value;
                      final maxVal = topCats.first.value;
                      final ratio = cat.value / maxVal;
                      final colors = [
                        AppColors.primary,
                        AppColors.blue,
                        AppColors.green,
                        AppColors.purple,
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                ['🥇', '🥈', '🥉', '4️⃣'][idx],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cat.key,
                                          style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          '${cat.value} recette${cat.value > 1 ? 's' : ''}',
                                          style: TextStyle(
                                              color: subColor, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                      valueColor: AlwaysStoppedAnimation(
                                          colors[idx]),
                                      minHeight: 7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: 20),
            ],

            // ── Plan de semaine ────────────────────────────────────────────────
            _sectionTitle(textColor, 'Plan de la semaine'),
            const SizedBox(height: 12),
            _card(cardColor,
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: planRate,
                            strokeWidth: 7,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.green),
                          ),
                          Center(
                            child: Text(
                              '${(planRate * 100).round()}%',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
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
                          Text('$filledSlots / $totalSlots repas planifiés',
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            planRate == 1
                                ? 'Semaine complète ! 🎉'
                                : planRate >= 0.5
                                    ? 'Bonne progression 👍'
                                    : 'Planifie encore quelques repas',
                            style:
                                TextStyle(color: subColor, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Budget : ${profile.weeklyBudget}€ / semaine · ${profile.persons} pers.',
                            style:
                                TextStyle(color: subColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )),

            const SizedBox(height: 20),

            // ── Badges ────────────────────────────────────────────────────────
            _sectionTitle(textColor, 'Badges'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _badges(totalXp, journal.length, favorites.length)
                  .map((b) => _BadgeTile(
                        badge: b,
                        cardColor: cardColor,
                        textColor: textColor,
                        subColor: subColor,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _heroCard(int totalXp, int level, int cooked, int favs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a0533), Color(0xFF2d1b4e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Niveau', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text('$level',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _levelLabel(level),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text('$totalXp XP',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text('${_xpToNextLevel(totalXp)} XP → niv.${level + 1}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStat(Color card, Color text, Color sub, String emoji,
          String value, String label) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(color: sub, fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _sectionTitle(Color textColor, String title) => Text(
        title,
        style: TextStyle(
            color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
      );

  Widget _card(Color bg, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  int _level(int xp) => (xp / 100).floor() + 1;
  int _xpToNextLevel(int xp) => (((_level(xp)) * 100) - xp).clamp(0, 100);
  String _levelLabel(int level) {
    if (level < 3) return 'Apprenti';
    if (level < 6) return 'Cuisinier';
    if (level < 10) return 'Chef';
    if (level < 15) return 'Chef Étoilé';
    return 'Maître Cuisinier';
  }

  List<_Badge> _badges(int xp, int cooked, int favs) => [
        _Badge('🍳', 'Premier plat', 'Cuisine ta 1ère recette', cooked >= 1),
        _Badge('📚', 'Explorateur', '5 recettes cuisinées', cooked >= 5),
        _Badge('👨‍🍳', 'Chef amateur', '10 recettes cuisinées', cooked >= 10),
        _Badge('⭐', 'Passionné', '20 recettes cuisinées', cooked >= 20),
        _Badge('💫', 'Centurion XP', '100 XP accumulés', xp >= 100),
        _Badge('🏆', 'Expert', '500 XP accumulés', xp >= 500),
        _Badge('❤️', 'Gourmet', '10 favoris', favs >= 10),
        _Badge('🔥', 'Légendaire', '1000 XP', xp >= 1000),
      ];
}

// ── Branch data ───────────────────────────────────────────────────────────────

class _Branch {
  final String id;
  final String emoji;
  final String label;
  final Color color;
  const _Branch(this.id, this.emoji, this.label, this.color);
}

const _branches = [
  _Branch('meat', '🥩', 'Viandes', AppColors.primary),
  _Branch('pastry', '🥐', 'Pâtisserie', Color(0xFFFF9900)),
  _Branch('veggie', '🥗', 'Végétarien', AppColors.green),
  _Branch('seafood', '🐟', 'Poissons', AppColors.blue),
  _Branch('breakfast', '🥞', 'Petit-déj', AppColors.yellow),
  _Branch('misc', '🍽️', 'Divers', AppColors.purple),
];

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge {
  final String emoji;
  final String title;
  final String desc;
  final bool unlocked;
  const _Badge(this.emoji, this.title, this.desc, this.unlocked);
}

class _BadgeTile extends StatelessWidget {
  final _Badge badge;
  final Color cardColor;
  final Color textColor;
  final Color subColor;

  const _BadgeTile({
    required this.badge,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.unlocked ? 1.0 : 0.35,
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: badge.unlocked
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.title,
                      style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(badge.desc,
                      style: TextStyle(color: subColor, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (badge.unlocked)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
